#!/usr/bin/env bash
# usage.sh — the non-blocking status reader for tmux-llm-usage.
#
# tmux calls this from a `#()` in the status line every `status-interval`
# seconds. It must return instantly: it only ever CATs a pre-rendered cache
# file. When the cache is older than the configured interval it kicks off a
# fully-detached background refresh (all std fds redirected, see ai-status.sh
# 164-219 for the range this pattern is modelled on) and STILL returns the old
# cache immediately. A slow or hung provider therefore never blocks the bar —
# you just keep seeing the last good value until the refresh lands.
#
# Config is written by the entry point (llm-usage.tmux) into a sourced file in
# the cache dir, so this hot path never has to call `tmux` — inside a `#()`
# subshell HOME="" and PATH/`tmux` are not guaranteed to be present.
#
# NEVER use `set -e`/`set -o pipefail`: this is called from the status line, so
# any non-zero from an absent cache or a failing provider is expected, not an
# error. On any failure we print an empty string (the capsule simply vanishes).

set -u

# A `#()` subshell can hand us a nearly empty PATH. Put the usual locations for
# coreutils and jq (Homebrew / /usr/local / system) in front of whatever we got.
PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:${PATH:-}"
export PATH

# ── cache dir (must match llm-usage.tmux) ────────────────────────────────────
cache_dir() {
  printf '%s/tmux-llm-usage-%s' "${TMUX_TMPDIR:-/tmp}" "$(id -u)"
}

CACHE_DIR="$(cache_dir)"
CONFIG="$CACHE_DIR/config.sh"     # sourced: LLM_PROVIDER / _INTERVAL / _FORMAT / _MAX / _TIMEOUT / _JQ
CACHE="$CACHE_DIR/segments"       # rendered tmux status string (what the bar shows)
RAW="$CACHE_DIR/last.json"        # last provider payload that parsed OK (kept for reference)
LOCKDIR="$CACHE_DIR/refresh.lock" # mkdir-based lock so refreshes never pile up

# Create the cache dir with 0700 and refuse to touch it if a symlink was
# pre-planted where we expect a real directory (defence against /tmp races).
ensure_cache_dir() {
  [ -L "$CACHE_DIR" ] && return 1
  [ -d "$CACHE_DIR" ] || ( umask 077; mkdir -p "$CACHE_DIR" ) 2>/dev/null || return 1
  [ -d "$CACHE_DIR" ] && [ ! -L "$CACHE_DIR" ]
}

# Portable file mtime (epoch seconds): BSD/macOS `-f %m`, then GNU `-c %Y`.
file_mtime() {
  stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null || echo 0
}

# Keep only a non-negative integer, else fall back to $2.
int_or() {
  case "$1" in
    '' | *[!0-9]*) printf '%s' "$2" ;;
    *) printf '%s' "$1" ;;
  esac
}

# ── config ───────────────────────────────────────────────────────────────────
# Defaults (overridden by the sourced config the entry point writes).
LLM_PROVIDER=''
LLM_INTERVAL='60'
LLM_FORMAT='label value'
LLM_MAX='4'
LLM_TIMEOUT='10'
LLM_JQ=''

load_config() {
  # shellcheck source=/dev/null
  [ -f "$CONFIG" ] && . "$CONFIG"
  LLM_INTERVAL="$(int_or "${LLM_INTERVAL:-}" 60)"
  LLM_MAX="$(int_or "${LLM_MAX:-}" 4)"
  LLM_TIMEOUT="$(int_or "${LLM_TIMEOUT:-}" 10)"
  [ "$LLM_MAX" -ge 1 ] 2>/dev/null || LLM_MAX=1
  [ "$LLM_TIMEOUT" -ge 1 ] 2>/dev/null || LLM_TIMEOUT=1
  # jq: prefer the absolute path the entry point resolved; else search PATH.
  [ -n "$LLM_JQ" ] && [ -x "$LLM_JQ" ] || LLM_JQ="$(command -v jq 2>/dev/null || true)"
}

# ── rendering ─────────────────────────────────────────────────────────────────
# Turn a provider JSON payload (on stdin) into the plain status string.
# Contract v1: {"v":1,"segments":[{"label":"CC 5H","value":"50%"},...]}.
# Tolerance: a missing "v" is treated as 1; only the first @llm-usage-max-segments
# segments are shown. Each `#` in provider DATA is escaped to `##` so a stray
# `#` in a value can never break tmux status formatting — style codes belong in
# the (trusted) format template, not in the (provider-supplied) data.
render() {
  "$LLM_JQ" -r \
    --arg fmt "$LLM_FORMAT" \
    --arg sep ' · ' \
    --argjson max "$LLM_MAX" '
    ( .segments // [] )
    | ( if type == "array" then . else [] end )
    | .[0:$max]
    | map(
        ( ( .label // "" ) | tostring | gsub("#"; "##") ) as $l
      | ( ( .value // "" ) | tostring | gsub("#"; "##") ) as $v
      | ( $fmt
          | gsub("label"; "\u0001") | gsub("value"; "\u0002")
          | gsub("\u0001"; $l)      | gsub("\u0002"; $v) )
      )
    | join($sep)
  ' 2>/dev/null
}

# Run the provider command string with a wall-clock timeout, print its stdout,
# and return its exit status (non-zero if it was killed for running too long).
# macOS has no `timeout(1)`, so we roll a tiny watchdog. Every helper subshell
# has all three std fds detached so command substitution never blocks on it
# (see the `$(...)` background-detach trap in bash-safety).
run_provider() {
  local secs="$1" cmd="$2" ofile cpid wpid rc
  ofile="$(mktemp "$CACHE_DIR/out.XXXXXX" 2>/dev/null)" || return 1
  sh -c "$cmd" >"$ofile" 2>/dev/null &
  cpid=$!
  ( sleep "$secs"; kill "$cpid" 2>/dev/null ) </dev/null >/dev/null 2>&1 &
  wpid=$!
  wait "$cpid" 2>/dev/null; rc=$?
  kill "$wpid" 2>/dev/null
  wait "$wpid" 2>/dev/null
  cat "$ofile" 2>/dev/null
  rm -f "$ofile" 2>/dev/null
  return "$rc"
}

# Do one refresh cycle: run the provider, and on a clean run with valid JSON
# overwrite the cache atomically; otherwise leave the last good value in place
# and just reset the staleness clock (so a broken provider shows the old value
# instead of hammering the endpoint every status-interval).
refresh() {
  ensure_cache_dir || return 0
  [ -n "$LLM_PROVIDER" ] || return 0
  [ -n "$LLM_JQ" ] && [ -x "$LLM_JQ" ] || return 0

  # Single-flight: if a refresh already holds the lock, bow out.
  mkdir "$LOCKDIR" 2>/dev/null || return 0
  # shellcheck disable=SC2064
  trap "rmdir '$LOCKDIR' 2>/dev/null" EXIT INT TERM

  local out rc rendered tmp
  out="$(run_provider "$LLM_TIMEOUT" "$LLM_PROVIDER")"
  rc=$?

  if [ "$rc" -eq 0 ] && printf '%s' "$out" | "$LLM_JQ" -e . >/dev/null 2>&1; then
    rendered="$(printf '%s' "$out" | render)"
    tmp="$(mktemp "$CACHE_DIR/seg.XXXXXX" 2>/dev/null)" || { touch "$CACHE" 2>/dev/null; return 0; }
    printf '%s' "$rendered" >"$tmp" && mv "$tmp" "$CACHE" 2>/dev/null
    printf '%s' "$out" >"$RAW.tmp" 2>/dev/null && mv "$RAW.tmp" "$RAW" 2>/dev/null
  else
    # Provider failed / timed out / emitted bad JSON: keep the last good cache
    # (create an empty one if there is none yet) and reset the clock.
    [ -e "$CACHE" ] || : >"$CACHE" 2>/dev/null
    touch "$CACHE" 2>/dev/null
  fi
}

# ── entry ──────────────────────────────────────────────────────────────────────
main() {
  ensure_cache_dir || { printf ''; exit 0; }
  load_config

  # Provider not configured yet: show nothing. The entry point is responsible
  # for the one-time "set @llm-usage-provider" hint at load time.
  if [ -z "$LLM_PROVIDER" ]; then
    printf ''
    exit 0
  fi

  # Refresh in the background if the cache is stale (or absent), then return the
  # current cache immediately. This is the non-blocking contract.
  local now mtime age
  now="$(date +%s 2>/dev/null || echo 0)"
  mtime="$(file_mtime "$CACHE")"
  age=$(( now - mtime ))
  if [ ! -s "$CACHE" ] || [ "$age" -gt "$LLM_INTERVAL" ]; then
    ( refresh ) </dev/null >/dev/null 2>&1 &
  fi

  cat "$CACHE" 2>/dev/null
  exit 0
}

# Test seam: `usage.sh __sync__` runs one refresh in the foreground (blocking)
# and prints the resulting cache. Used by the smoke test and by anyone who wants
# a deterministic one-shot; the normal `#()` call path never uses it.
case "${1:-}" in
  __sync__)
    ensure_cache_dir || { printf ''; exit 0; }
    load_config
    if [ -z "$LLM_PROVIDER" ]; then printf ''; exit 0; fi
    refresh
    cat "$CACHE" 2>/dev/null
    exit 0
    ;;
  *)
    main
    ;;
esac

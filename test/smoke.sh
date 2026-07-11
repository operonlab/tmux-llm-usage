#!/usr/bin/env bash
# smoke.sh — end-to-end functional test on a fully isolated tmux socket.
#
# It never touches your real tmux server: a PATH shim rewrites every bare `tmux`
# (including the ones the plugin runs internally) to `tmux -L <private-socket>`,
# and TMUX_TMPDIR is redirected to a short throwaway dir. Cleaned up on exit.
#
# Usage: test/smoke.sh   (exit 0 = all checks passed)

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REAL_TMUX="$(command -v tmux)" || { echo "FATAL: tmux not on PATH"; exit 2; }
command -v jq >/dev/null 2>&1   || { echo "FATAL: jq not on PATH"; exit 2; }

SOCK="llmu-smoke-$$"
TT="$(mktemp -d /tmp/llmu.XXXXXX)"          # short path (macOS unix-socket limit)
SHIMDIR="$(mktemp -d /tmp/llmush.XXXXXX)"
CDIR="$TT/tmux-llm-usage-$(id -u)"
HITS="$TT/hits"

cat > "$SHIMDIR/tmux" <<EOF
#!/bin/sh
exec "$REAL_TMUX" -L "$SOCK" "\$@"
EOF
chmod +x "$SHIMDIR/tmux"
PATH="$SHIMDIR:$PATH"; export PATH
export TMUX_TMPDIR="$TT"

cleanup() { tmux kill-server 2>/dev/null; rm -rf "$SHIMDIR" "$TT"; }
trap cleanup EXIT INT TERM

fails=0
pass() { printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1"; fails=$((fails + 1)); }
contains() { case "$2" in *"$1"*) return 0;; *) return 1;; esac; }

reload() { "$ROOT/llm-usage.tmux"; }
sync()   { "$ROOT/scripts/usage.sh" __sync__; }

# ── setup: isolated server with the token in status-right ────────────────────
tmux -f /dev/null new-session -d -s s
tmux set-option -g status-right "cpu #{llm_usage} end"
tmux set-option -g @llm-usage-provider "$ROOT/examples/static.sh"
tmux set-option -g @llm-usage-interval 60
reload

# 1) interpolation
sr="$(tmux show-option -gqv status-right)"
if contains "#($ROOT/scripts/usage.sh)" "$sr"; then pass "token -> #() interpolated"; else fail "interpolation ($sr)"; fi

# 2) static provider renders expected segments
out="$(sync)"
if contains "CC 5H 50%" "$out" && contains " · " "$out"; then pass "static render [$out]"; else fail "static render [$out]"; fi

# 3) max-segments truncation
tmux set-option -g @llm-usage-max-segments 2; reload
n="$(sync | awk -F' · ' '{print NF}')"
if [ "$n" = "2" ]; then pass "max-segments truncates to 2"; else fail "max-segments got $n"; fi
tmux set-option -g @llm-usage-max-segments 4; reload

# 4) custom format template (proves label/value substitution is corruption-safe)
tmux set-option -g @llm-usage-format "[label:value]"; reload
out="$(sync)"
if contains "[CC 5H:50%]" "$out"; then pass "custom format"; else fail "custom format [$out]"; fi
tmux set-option -g @llm-usage-format "label value"; reload

# establish a known-good baseline for the resilience tests
good="$(sync)"

# 5) broken JSON keeps the last good value (no error text leaks)
tmux set-option -g @llm-usage-provider "echo 'not json at all'"; reload
out="$(sync)"
if [ "$out" = "$good" ] && ! contains "not json" "$out"; then pass "broken JSON keeps cache"; else fail "broken JSON [$out]"; fi

# 6) non-zero exit keeps the last good value
tmux set-option -g @llm-usage-provider "printf '%s' '{\"v\":1,\"segments\":[]}'; exit 7"; reload
out="$(sync)"
if [ "$out" = "$good" ]; then pass "failing provider keeps cache"; else fail "failing provider [$out]"; fi

# 7) a hung provider hits the timeout and keeps the last good value
tmux set-option -g @llm-usage-timeout 1
tmux set-option -g @llm-usage-provider "sleep 8; echo '{\"v\":1,\"segments\":[{\"label\":\"X\",\"value\":\"9\"}]}'"; reload
t0=$(date +%s); out="$(sync)"; t1=$(date +%s)
if [ "$out" = "$good" ] && [ $((t1 - t0)) -lt 4 ]; then pass "timeout keeps cache ($((t1 - t0))s)"; else fail "timeout [$out] $((t1 - t0))s"; fi
tmux set-option -g @llm-usage-timeout 10

# 8) fresh-cache foreground read does NOT re-run the provider (non-blocking path)
cat > "$TT/counting-provider.sh" <<EOF
#!/bin/sh
echo run >> "$HITS"
printf '%s' '{"v":1,"segments":[{"label":"N","value":"1"}]}'
EOF
chmod +x "$TT/counting-provider.sh"
tmux set-option -g @llm-usage-provider "$TT/counting-provider.sh"; reload
sync >/dev/null                      # prime: provider runs once, cache is now fresh
before="$(wc -l < "$HITS" | tr -d ' ')"
TIMEFORMAT='%R'; { time "$ROOT/scripts/usage.sh" >/dev/null; } 2>"$TT/ms"
after="$(wc -l < "$HITS" | tr -d ' ')"
secs="$(cat "$TT/ms")"
if [ "$before" = "$after" ]; then pass "fresh read skips provider (cache-only, ${secs}s)"; else fail "fresh read re-ran provider ($before->$after)"; fi
# coarse timing guard (typical is well under 0.1s; generous ceiling avoids CI flake)
if awk -v s="$secs" 'BEGIN{exit !(s < 0.5)}'; then pass "foreground read fast (${secs}s)"; else fail "foreground read slow (${secs}s)"; fi

# 9) teardown restores the token and removes the cache dir
"$ROOT/scripts/teardown.sh"
sr="$(tmux show-option -gqv status-right)"
if contains "#{llm_usage}" "$sr"; then pass "teardown restores token"; else fail "teardown token ($sr)"; fi
if [ ! -d "$CDIR" ]; then pass "teardown removes cache dir"; else fail "cache dir remains"; fi

echo "----"
if [ "$fails" -eq 0 ]; then echo "ALL SMOKE CHECKS PASSED"; else echo "$fails CHECK(S) FAILED"; fi
exit "$fails"

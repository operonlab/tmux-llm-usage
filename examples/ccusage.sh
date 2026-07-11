#!/usr/bin/env bash
# ccusage.sh — TEMPLATE provider wrapping the `ccusage` npm CLI, which reads
# Claude Code's local usage logs. https://github.com/ryoppippi/ccusage
#
# There is nothing secret here (ccusage reads local files), but this is still a
# TEMPLATE: ccusage's JSON schema changes between versions, so treat the jq
# extraction below as a starting point and adapt the field names to whatever
# `ccusage daily --json` prints on YOUR machine. As always, if you add any HTTP
# variant, keep endpoints/keys in environment variables — never in this file.
#
# Requires: ccusage (or `npx ccusage`) + jq.
# Contract v1: {"v":1,"segments":[{"label","value"},...]}

set -u

command -v jq >/dev/null 2>&1 || exit 0

# Prefer an installed `ccusage`, fall back to `npx ccusage`. Print nothing if
# neither is available (capsule keeps its last value).
if command -v ccusage >/dev/null 2>&1; then
  raw="$(ccusage daily --json 2>/dev/null)" || exit 0
elif command -v npx >/dev/null 2>&1; then
  raw="$(npx --yes ccusage daily --json 2>/dev/null)" || exit 0
else
  exit 0
fi

[ -n "$raw" ] || exit 0

# ADAPT: this reads the most recent day's cost + total tokens from the shape
# `{ "daily": [ { "date", "totalCost", "totalTokens" }, ... ] }`. Check your
# ccusage output (`ccusage daily --json | jq`) and rename fields as needed.
printf '%s' "$raw" | jq -c '
  ( .daily // [] ) | (if type == "array" then . else [] end) as $days
  | ( $days | last ) as $today
  | { v: 1,
      segments: (
        if $today == null then []
        else
          [ ( if ($today.totalCost // null) != null
              then { label: "CC $", value: ("$" + (($today.totalCost) | (. * 100 | round / 100) | tostring)) }
              else empty end ),
            ( if ($today.totalTokens // null) != null
              then { label: "CC tok", value: (($today.totalTokens) | tostring) }
              else empty end ) ]
        end
      ) }
' 2>/dev/null || exit 0

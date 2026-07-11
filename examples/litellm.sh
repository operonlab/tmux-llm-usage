#!/usr/bin/env bash
# litellm.sh — TEMPLATE provider that turns a self-hosted LiteLLM spend endpoint
# into a contract-v1 payload for tmux-llm-usage.
#
# ┌── FILL THIS IN ────────────────────────────────────────────────────────────┐
# │ Set these two in your ENVIRONMENT (e.g. ~/.zshenv or a sourced secrets      │
# │ file) — never write a key into this file, it lives in a git repo:           │
# │     export LITELLM_BASE_URL="https://litellm.example.com"                   │
# │     export LITELLM_API_KEY="sk-..."                                         │
# └────────────────────────────────────────────────────────────────────────────┘
#
# It calls LiteLLM's spend endpoint and emits one segment. Adjust the endpoint,
# the jq extraction, and the label/threshold to match YOUR LiteLLM deployment —
# spend schemas differ between versions. If anything is missing or the call
# fails, it prints nothing so the plugin keeps showing the last good value.
#
# Requires: curl, jq. Contract v1: {"v":1,"segments":[{"label","value"},...]}

set -u

BASE="${LITELLM_BASE_URL:-}"
KEY="${LITELLM_API_KEY:-}"

# Not configured yet → print nothing (the capsule just stays on its last value).
[ -n "$BASE" ] && [ -n "$KEY" ] || exit 0
command -v curl >/dev/null 2>&1 || exit 0
command -v jq   >/dev/null 2>&1 || exit 0

# Example: LiteLLM exposes aggregate spend at /global/spend/report (admin key).
# Change this path + the jq filter below to whatever your instance returns.
resp="$(curl -fsS --max-time 8 \
  -H "Authorization: Bearer ${KEY}" \
  "${BASE%/}/global/spend/report" 2>/dev/null)" || exit 0

# Pull a dollar figure out of the response and format it as one segment. This
# jq is deliberately defensive: if the field is absent it yields "" and the
# whole thing prints an empty segment list rather than crashing.
printf '%s' "$resp" | jq -c '
  # ADAPT: replace `.total_spend` with the field your LiteLLM version returns.
  ( .total_spend // .spend // empty ) as $spend
  | { v: 1,
      segments: (
        if $spend == null then []
        else [ { label: "LLM $", value: ("$" + ($spend | (. * 100 | round / 100) | tostring)) } ]
        end
      ) }
' 2>/dev/null || exit 0

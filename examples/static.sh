#!/usr/bin/env bash
# static.sh — the simplest possible provider: print a fixed contract-v1 payload.
#
# TEMPLATE — this one needs no editing; it exists so a non-technical user can
# point @llm-usage-provider at it and see the capsule light up in ~30 seconds,
# then copy litellm.sh / ccusage.sh and wire in their real numbers.
#
# A provider is ANY command that prints this JSON on stdout. Nothing here is
# secret, but the golden rule for the real ones still applies: put endpoints and
# API keys in environment variables, never hard-code them into a provider file.
#
# Contract v1: {"v":1,"segments":[{"label":"...","value":"..."},...]}

set -u

cat <<'JSON'
{
  "v": 1,
  "segments": [
    { "label": "CC 5H", "value": "50%" },
    { "label": "CC 7D", "value": "80%" },
    { "label": "CX 5H", "value": "12%" }
  ]
}
JSON

# Provider Contract v1

A **provider** is any command you configure via `@llm-usage-provider`. The
plugin runs it in the background on a timer and renders its output into the
status line. This document is the complete contract that command must satisfy.

## The command

- It may be anything runnable through `sh -c`: a script path, a one-liner, a
  pipeline. Example: `set -g @llm-usage-provider "~/bin/my-usage.sh"`.
- It runs with a **timeout** (`@llm-usage-timeout`, default 10s). If it takes
  longer it is killed and the previous value is kept.
- It **runs code you supply.** Only configure it in a `tmux.conf` you trust.
  Keep endpoints and secrets in environment variables, never in the provider
  file (provider files often live in a git repo).

## Output: one JSON object on stdout

```json
{
  "v": 1,
  "segments": [
    { "label": "CC 5H", "value": "50%" },
    { "label": "CC 7D", "value": "80%" }
  ]
}
```

### Fields

| Field | Type | Required | Meaning |
|---|---|---|---|
| `v` | number | no | Contract version. Currently `1`. **A missing `v` is treated as `1`.** |
| `segments` | array | yes | Ordered list of segments to render, left to right. |
| `segments[].label` | string | no | Short caption (e.g. a window like `CC 5H`). Missing ⇒ empty. |
| `segments[].value` | string | no | The value (e.g. `50%`, `$12.30`). Numbers are accepted and stringified. Missing ⇒ empty. |

Only the first `@llm-usage-max-segments` (default 4) segments are shown; the
rest are ignored so the bar stays tidy.

### Everything on **stdout**, nothing else

Write the JSON to standard output. Send any diagnostics/logs to standard error —
they are discarded and never reach the status line.

## Rendering

Each surviving segment is rendered with `@llm-usage-format` (default
`label value`): the words `label` and `value` are replaced with that segment's
data. Segments are joined with ` · `.

- Custom text: `@llm-usage-format "[label:value]"` → `[CC 5H:50%]`.
- Custom colour: `@llm-usage-format "#[fg=green]label#[default] value"` — tmux
  style codes in the (trusted) format template are honoured.
- Any `#` inside provider **data** (labels/values) is escaped to `##`, so a
  stray `#` in a value can never accidentally trigger tmux formatting. Put style
  codes in the format template, not in your data.

## Error tolerance (this is the whole point)

The status bar must never break, so the plugin degrades quietly:

| Situation | Result |
|---|---|
| Provider prints valid JSON | Cache is updated; new value shown. |
| Provider prints **broken JSON** | **Last good value is kept** (never an error string). |
| Provider exits non-zero | Last good value is kept. |
| Provider exceeds the timeout | Provider is killed; last good value is kept. |
| Provider prints valid JSON with an empty `segments` | Capsule renders empty (you asked for nothing). |
| `jq` not installed | Capsule is empty; a one-time hint is shown at load. |

Because the caller only ever reads a cached file, none of the above ever blocks
your status line.

## Non-blocking model

1. tmux evaluates `#(scripts/usage.sh)` every `status-interval` seconds.
2. `usage.sh` reads the cache file and returns **immediately**.
3. If the cache is older than `@llm-usage-interval`, it launches a
   **fully detached** background refresh (all std fds redirected) and *still*
   returns the old cache in the same call.
4. The background refresh runs your provider (with the timeout), and on success
   atomically replaces the cache. A single-flight lock prevents overlapping
   refreshes.

The result: the foreground call is a cache read (typically well under 100 ms),
and a slow, failing, or hung provider only ever means "the number is a little
stale", never a frozen bar.

## A minimal provider

```sh
#!/usr/bin/env bash
# Prints a single segment. Replace the echo with your real lookup.
printf '{"v":1,"segments":[{"label":"CC 5H","value":"%s"}]}\n' "$(my_quota_percent)"
```

See [`../examples/`](../examples/) for `static.sh` (canned demo), `litellm.sh`
(self-hosted LiteLLM spend), and `ccusage.sh` (the `ccusage` npm CLI).

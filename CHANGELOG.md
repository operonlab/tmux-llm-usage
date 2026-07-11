# Changelog

All notable changes to tmux-llm-usage are documented here. This project follows
[Semantic Versioning](https://semver.org/).

## [0.1.0] - 2026-07-11

Initial release.

### Added
- **Provider contract v1**: point `@llm-usage-provider` at any command whose
  stdout is `{"v":1,"segments":[{"label","value"},...]}`. A missing `v` is
  treated as `1`; broken JSON, a non-zero exit, or a timeout keeps the last good
  value instead of showing an error. Full spec in
  [docs/provider-contract.md](docs/provider-contract.md).
- **Non-blocking status reader** (`scripts/usage.sh`): the `#()` call only ever
  reads a pre-rendered cache and returns instantly; a stale cache triggers a
  fully-detached background refresh (all std fds redirected) that still returns
  the old value in the same call. A single-flight lock prevents overlapping
  refreshes and a portable watchdog enforces `@llm-usage-timeout`.
- **`#{llm_usage}` interpolation** (`llm-usage.tmux`): the entry point replaces
  the literal token in `status-left` / `status-right` with the reader call, and
  writes a sourced config file so the hot path never has to invoke `tmux`.
- **Options**: `@llm-usage-provider` (required), `@llm-usage-interval` (60),
  `@llm-usage-format` (`label value`, joined by ` · `),
  `@llm-usage-max-segments` (4), `@llm-usage-timeout` (10).
- **Examples**: `static.sh` (canned 30-second demo), `litellm.sh` (self-hosted
  LiteLLM spend template), `ccusage.sh` (the `ccusage` npm CLI). Each marked as
  a template with secrets kept in environment variables.
- First-load `display-message` hints when the required provider is unset or when
  `jq` is missing.
- `scripts/teardown.sh` for clean removal (restore the token + delete the cache
  directory).
- Headless smoke test (`test/smoke.sh`) on an isolated tmux socket, plus an
  Ubuntu shellcheck + functional-smoke CI workflow.

### Notes
- Requires tmux **2.2+** (user options confirmed present in the official CHANGES
  since 2.2) and `jq`. Built and tested on macOS with tmux `next-3.8`; the
  mechanism is portable POSIX `sh` + `jq`.
- The plugin ships **no** data collectors on purpose — every usage source is
  different, so you bring your own provider. This is the family's
  differentiation core.

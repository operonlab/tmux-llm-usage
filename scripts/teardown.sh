#!/usr/bin/env bash
# teardown.sh — cleanly "uninstall" tmux-llm-usage from a running server without
# restarting tmux. It (1) turns any injected `#(scripts/usage.sh)` back into the
# original `#{llm_usage}` token in status-left / status-right, and (2) removes
# the plugin's cache directory. Safe to run repeatedly and safe to run when
# nothing was installed. NEVER use `set -e`: absent bindings/options are normal.

set -u

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USAGE_SCRIPT="$CURRENT_DIR/usage.sh"
TOKEN='#{llm_usage}'
REPL="#($USAGE_SCRIPT)"

# Reverse the interpolation in each status option (quoted pattern = literal
# match, so the parentheses/dots in the path are matched verbatim).
for option in status-left status-right; do
  value="$(tmux show-option -gqv "$option" 2>/dev/null)"
  case "$value" in
    *"$REPL"*)
      tmux set-option -gq "$option" "${value//"$REPL"/$TOKEN}"
      ;;
  esac
done

# Remove the cache dir (only our own, 0700, under TMUX_TMPDIR/tmp — never a
# symlink, which we refuse to follow).
cdir="${TMUX_TMPDIR:-/tmp}/tmux-llm-usage-$(id -u)"
if [ -d "$cdir" ] && [ ! -L "$cdir" ]; then
  rm -rf "$cdir" 2>/dev/null
fi

exit 0

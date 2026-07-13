# tmux-llm-usage hero screenshot — recorded with vhs (https://github.com/charmbracelet/vhs)
#   cd tmux-llm-usage && vhs docs/screenshot.tape
#
# Freezes on the money shot: the AI-usage capsule rendered in the tmux status
# bar, driven by the bundled examples/static.sh provider (a fixed contract-v1
# payload) so it is deterministic and needs no real quota endpoint. Requires jq.
#
# Runs in a throwaway, isolated tmux server (-L shot-tmux-llm-usage, -f /dev/null)
# so it never touches your real tmux. This complements docs/demo.tape (the GIF);
# it exists to produce a single large, crisp still for the README hero.

Output "/private/tmp/claude-501/-Users-joneshong/aaff1254-ec36-4c2f-98bf-76d62cc8b483/scratchpad/hero-shots/tmux-llm-usage/_throwaway.gif"

Set Shell "bash"
Set FontFamily "MesloLGS Nerd Font Mono"
Set FontSize 20
Set Width 1600
Set Height 420
Set Padding 20
Set TypingSpeed 1ms

Hide
Type `tmux -L shot-tmux-llm-usage -f /dev/null new-session -d -s cap -x 130 -y 14 'bash --norc'`
Enter
Type `tmux -L shot-tmux-llm-usage attach -t cap`
Enter
Sleep 400ms
Type `PS1='$ '; clear`
Enter

# A modern, high-contrast status bar so the capsule reads cleanly in a still.
Type `tmux -L shot-tmux-llm-usage set -g status-interval 2 \; set -g status-right-length 220`
Enter
Type `tmux -L shot-tmux-llm-usage set -g status-style 'bg=colour236,fg=colour250'`
Enter
Type `tmux -L shot-tmux-llm-usage set -g window-status-current-style 'bg=colour31,fg=colour231,bold'`
Enter
Type `tmux -L shot-tmux-llm-usage set -g status-left ' #[bg=colour31,fg=colour231,bold] tmux #[default] '`
Enter
Type `tmux -L shot-tmux-llm-usage set -g status-left-length 20`
Enter

# The plugin's own knobs: color the label dim, the value bright, and point the
# provider at the bundled static.sh so the numbers are fixed and safe.
Type `tmux -L shot-tmux-llm-usage set -g @llm-usage-format '#[fg=colour246]label #[fg=colour84,bold]value#[default]'`
Enter
Type `tmux -L shot-tmux-llm-usage set -g @llm-usage-interval 2`
Enter
Type `tmux -L shot-tmux-llm-usage set -g @llm-usage-provider "$PWD/examples/static.sh"`
Enter
Type `tmux -L shot-tmux-llm-usage set -g status-right '#[fg=colour45,bold]AI usage#[default]  #{llm_usage} '`
Enter

Type `./llm-usage.tmux`
Enter
Type `./scripts/usage.sh __sync__`
Enter
Type `clear`
Enter
Sleep 2500ms

Type `# tmux-llm-usage — your AI quota / spend, live in the status bar`
Sleep 800ms
Show
Sleep 400ms
Screenshot docs/screenshot.png
Sleep 200ms

Hide
Type `tmux -L shot-tmux-llm-usage kill-server`
Enter
Sleep 300ms

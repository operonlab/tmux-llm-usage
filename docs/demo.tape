# tmux-llm-usage demo — recorded with vhs (https://github.com/charmbracelet/vhs)
#   cd tmux-llm-usage && vhs docs/demo.tape
#
# Runs in a throwaway, isolated tmux server (-L vhsdemo-llm-usage,
# -f /dev/null) so it never touches your real tmux. It uses the bundled
# examples/static.sh provider (a fixed contract-v1 payload) so the capsule
# is deterministic and needs no real quota endpoint. Requires jq.

Output "docs/demo.gif"
Set Shell "bash"
Set FontSize 15
Set Width 1200
Set Height 660
Set Padding 12
Set TypingSpeed 40ms

Hide
Type `tmux -L vhsdemo-llm-usage -f /dev/null new-session -d -s demo 'bash --norc -i'`
Enter
Type `tmux -L vhsdemo-llm-usage attach -t demo`
Enter
Sleep 800ms
Type `PS1='❯ '; clear`
Enter
Type `tmux -L vhsdemo-llm-usage set -g status-interval 2 \; set -g status-right-length 200`
Enter
Type `tmux -L vhsdemo-llm-usage set -g @llm-usage-interval 2`
Enter
Type `tmux -L vhsdemo-llm-usage set -g @llm-usage-provider "$PWD/examples/static.sh"`
Enter
Type `tmux -L vhsdemo-llm-usage set -g status-right ' usage #{llm_usage} '`
Enter
Type `./llm-usage.tmux`
Enter
Type `./scripts/usage.sh __sync__`
Enter
Type "clear"
Enter
Sleep 2s
Show
Type "# tmux-llm-usage: your quota / spend in the status bar (bring your own data)"
Enter
Sleep 4.5s
Hide
Type `tmux -L vhsdemo-llm-usage kill-server`
Enter
Sleep 500ms

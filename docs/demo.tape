# tmux-llm-usage demo — your LLM quota / spend as a capsule in a two-row cockpit
# status bar. Fully self-contained: docs/demo-setup.sh stages an anonymous shell
# and a catppuccin-mocha ISOLATED tmux server (socket lu-demo), then loads the
# plugin so scripts/usage.sh renders the LLM capsule from the bundled
# examples/static.sh provider (a fixed contract-v1 payload — no real endpoint or
# API key). The cockpit owns both status rows; the LLM quota capsule sits on the
# left of Row 2 (its real feature), a staged system capsule on the right.
# Requires jq. Re-record from the repo root with:  vhs docs/demo.tape
Output "docs/demo.gif"
Require tmux

Set Shell "bash"
Set FontFamily "MesloLGS Nerd Font Mono"
Set FontSize 20
Set Width 2392
Set Height 806
Set Padding 20
Set TypingSpeed 35ms

Hide
Type "bash docs/demo-setup.sh"
Enter
Sleep 3s
Type "clear; tmux -L lu-demo attach -t demo"
Enter
Sleep 2500ms
Show

# the cockpit: Row 2 left = the LLM quota capsule (CC 5H / CC 7D / CX 5H)
Sleep 3s
Type "# tmux-llm-usage: your quota / spend as a capsule in the status bar"
Enter
Sleep 2500ms
Type "# the provider is any command that prints usage JSON (here: examples/static.sh)"
Enter
Sleep 4s

Hide
Ctrl+B
Type "d"
Sleep 400ms
Type "tmux -L lu-demo kill-server"
Enter
Sleep 500ms

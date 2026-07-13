# tmux-llm-usage demo — your LLM quota / spend as a capsule in a cockpit status
# bar. Fully self-contained: docs/demo-setup.sh stages an anonymous shell and a
# catppuccin-mocha ISOLATED tmux server (socket lu-demo), then loads the plugin
# so the #{llm_usage} token renders from the bundled examples/static.sh provider
# (a fixed contract-v1 payload — no real endpoint or API key). The theme owns
# status-left AND status-right (the default status-right leaks the hostname); the
# capsule sits at the tail, behind the clock. Requires jq.
# Re-record from the repo root with:  vhs docs/demo.tape
Output "docs/demo.gif"
Require tmux

Set Shell "bash"
Set FontFamily "MesloLGS Nerd Font Mono"
Set FontSize 20
Set Width 1600
Set Height 480
Set Padding 20
Set TypingSpeed 35ms

Hide
Type "bash docs/demo-setup.sh"
Enter
Sleep 3s
Type "clear; tmux -L lu-demo attach -t demo"
Enter
Sleep 2s
Show

# the cockpit: clock capsule, then the LLM usage capsule (CC 5H / CC 7D / CX 5H)
Sleep 3s
Type "# tmux-llm-usage: your quota / spend in the status bar — bring your own provider"
Enter
Sleep 3s
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

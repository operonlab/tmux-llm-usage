# tmux-llm-usage hero screenshot — recorded with vhs (https://github.com/charmbracelet/vhs)
#   cd tmux-llm-usage && vhs docs/screenshot.tape
#
# Freezes on the money shot: the two-row pill cockpit (family-consistent
# catppuccin-mocha, half-circle end-caps) with THIS plugin's real feature — the
# LLM quota capsule — on the left of Row 2, rendered from scripts/usage.sh
# reading the bundled examples/static.sh provider (a fixed contract-v1 payload,
# so it is deterministic and needs no real quota endpoint or API key). Requires jq.
#
# Fully self-contained and anonymous by construction: docs/demo-setup.sh stages
# an identity-free shell + a throwaway ISOLATED tmux server (socket lu-demo, its
# own config) — your real tmux server and config are never touched, and no
# hostname / username / home path leaks. This complements docs/demo.tape (the
# GIF); it exists to produce a single large, crisp still for the README hero.

Output "/tmp/vhs-llm-usage-hero.gif"

Set Shell "bash"
Set FontFamily "MesloLGS Nerd Font Mono"
Set FontSize 20
Set Width 2392
Set Height 400
Set Padding 20
Set TypingSpeed 12ms

Hide
Type "bash docs/demo-setup.sh"
Enter
Sleep 3s
Type "clear; tmux -L lu-demo attach -t demo"
Enter
Sleep 2500ms
Show

# narration above the two-row cockpit — the money shot is the LLM quota capsule
# on the left of Row 2 (CC 5H / CC 7D / CX 5H), rendered from scripts/usage.sh.
Type "# tmux-llm-usage: your LLM quota / spend as a capsule in the status bar"
Enter
Sleep 900ms
Type "# the provider is any command that prints usage JSON (here: examples/static.sh)"
Enter
Sleep 1500ms
Screenshot docs/screenshot.png
Sleep 200ms

Hide
Ctrl+B
Type "d"
Sleep 400ms
Type "tmux -L lu-demo kill-server"
Enter
Sleep 500ms

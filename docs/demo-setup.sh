#!/bin/bash
# demo-setup.sh — self-contained stage for docs/demo.tape. Builds everything the
# recording needs and starts an ISOLATED tmux server (socket: lu-demo, own
# config) — your real tmux server and config are never touched.
#
# Anonymous by construction: an identity-free shell prompt and a cockpit theme
# that OWNS both status rows (the default tmux status-right prints the machine's
# hostname — the cockpit format replaces it so nothing leaks).
#
# FAMILY-CONSISTENT: the same two-row pill cockpit as the rest of the plugin
# family (catppuccin mocha, half-circle end-caps). Row 1 = session / window /
# cluster / weather-clock chrome; Row 2 left = the LLM quota capsule (THIS
# plugin's real feature), Row 2 right = a staged NET/CPU/MEM/DISK capsule (demo
# chrome).
#
# HONEST BY DESIGN: the LLM capsule is driven by the plugin's own
# scripts/usage.sh reader (a #() call, non-blocking, cache-backed) — the same
# hot path llm-usage.tmux rewrites #{llm_usage} into. The numbers come from the
# bundled examples/static.sh provider (a fixed contract-v1 payload), so the
# capsule is deterministic and needs no real quota endpoint or API key. (The
# reader token would normally live in status-left/right, which the plugin does
# rewrite; here the cockpit drives status-format instead — which the plugin does
# NOT rewrite — so the reader is wired directly as a #() call.) Requires jq.
set -u
unset TMUX TMUX_PANE
SOCK=lu-demo
WORK=/tmp/vhs-llm-usage-demo
PLUGIN="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMUX_BIN="${TMUX_BIN:-tmux}"
USAGE="$PLUGIN/scripts/usage.sh"

mkdir -p "$WORK"

# ── glyphs (byte escapes) + mocha palette ──
CAPL=$(printf '\xee\x82\xb6'); CAPR=$(printf '\xee\x82\xb4'); SEP=$(printf '\xee\x82\xb0')
I_TERM=$(printf '\xee\x9e\x95');   I_ROBOT=$(printf '\xf3\xb0\x9a\xa9')
I_PLAY=$(printf '\xef\x81\x8b');   I_PAUSE=$(printf '\xef\x81\x8c')
I_FLEET=$(printf '\xef\x84\x88');  I_CAL=$(printf '\xef\x86\xae')
I_THERMO=$(printf '\xef\x8b\x89'); I_CLOCK=$(printf '\xef\x80\x97')
I_NET=$(printf '\xef\x83\xac');    I_CPU=$(printf '\xf3\xb0\x93\x85')
I_MEM=$(printf '\xf3\xb0\x8d\x9b');I_DISK=$(printf '\xef\x82\xa0')
I_CLAUDE=$(printf '\xef\x81\xa9'); I_CODEX=$(printf '\xef\x84\xa1'); I_GEMINI=$(printf '\xef\x86\xa0')
BG='#1E1E1E'; CRUST='#11111b'; FG='#cdd6f4'; SURF='#313244'
PEACH='#fab387'; YELLOW='#f9e2af'; MAROON='#eba0ac'; LAVENDER='#b4befe'
MAUVE='#cba6f7'; PINK='#f5c2e7'; BLUE='#89b4fa'; SKY='#89dceb'
SAPPHIRE='#74c7ec'; TEAL='#94e2d5'; GREEN='#a6e3a1'; RED='#f38ba8'

p_open()  { printf '#[fg=%s,bg=%s]%s#[fg=%s,bg=%s]%s  ' "$1" "$BG" "$CAPL" "$CRUST" "$1" "$2"; }
p_text()  { printf '#[fg=%s,bg=%s] %s ' "$FG" "$SURF" "$1"; }
p_badge() { printf '#[fg=%s,bg=%s]%s#[fg=%s,bg=%s]%s ' "$1" "$SURF" "$CAPL" "$CRUST" "$1" "$2"; }
p_ibadge(){ printf '#[fg=%s,bg=%s]%s#[fg=%s,bg=%s]%s  ' "$1" "$SURF" "$CAPL" "$CRUST" "$1" "$2"; }
p_close() { printf '#[fg=%s,bg=%s]%s ' "$SURF" "$BG" "$CAPR"; }

# ── Row 1 pieces: session pill · window chips · cluster capsule · right pill ──
LEFT_R1="#[fg=$GREEN,bg=$BG]${CAPL}#[fg=$CRUST,bg=$GREEN]${I_TERM}  #[fg=$FG,bg=$SURF] #S #[fg=$SURF,bg=$BG]${CAPR} "
WINF="#[fg=$CRUST,bg=#9399b2]#[fg=$BG,reverse]${CAPL}#[none]#I #[fg=$FG,bg=$SURF] #W "
WINCUR="#[fg=$CRUST,bg=$PEACH]#[fg=$BG,reverse]${CAPL}#[none]#I #[fg=$FG,bg=#45475a] #W "
CLUSTER="#[fg=$MAUVE,bg=$BG]${CAPL}#[fg=$CRUST,bg=$MAUVE]${I_ROBOT}  #[fg=$FG,bg=$SURF] ${I_PLAY} 1  ${I_PAUSE} 8 #[fg=$SAPPHIRE,bg=$SURF]${CAPL}#[fg=$CRUST,bg=$SAPPHIRE]${I_FLEET}  #[fg=$FG,bg=$SURF] #[fg=$GREEN,bg=$SURF]M #[fg=$GREEN,bg=$SURF]W #[fg=$RED,bg=$SURF]A #[fg=$SURF,bg=$BG]${CAPR}"
RIGHT_R1="#[fg=$PINK,bg=$BG]${CAPL}#[fg=$CRUST,bg=$PINK]${I_CAL}  #[fg=$FG,bg=$SURF] #W #[fg=$SKY,bg=$SURF]${CAPL}#[fg=$CRUST,bg=$SKY]${I_THERMO}  #[fg=$FG,bg=$SURF] 🌤️ 29°C #[fg=$SAPPHIRE,bg=$SURF]${CAPL}#[fg=$CRUST,bg=$SAPPHIRE]${I_CLOCK}  #[fg=$FG,bg=$SURF] %Y/%m/%d %H:%M #[fg=$SURF,bg=$BG]${CAPR}"
FMT0="#[align=left bg=$BG]${LEFT_R1}#[list=on]#{W:#{T:@pw-fmt},#{T:@pw-cur}}#[nolist align=right]${RIGHT_R1}#[align=absolute-centre]${CLUSTER}"

# ── Row 2: LLM quota capsule (left, THIS plugin's REAL scripts/usage.sh reader
#    wired directly since status-format isn't rewritten) · staged net/cpu/mem/disk
#    capsule (right, demo chrome — static values) ──
ROW2_L="$(p_open "$MAUVE" "$I_ROBOT")$(p_text LLM)$(p_badge "$PEACH" "$I_CLAUDE")$(p_text "#('$USAGE')")$(p_close)"
ROW2_R="$(p_open "$TEAL" "$I_NET")$(p_text '1.4M/s')$(p_ibadge "$GREEN" "$I_CPU")$(p_text 18%%)$(p_ibadge "$YELLOW" "$I_MEM")$(p_text 47%%)$(p_ibadge "$PEACH" "$I_DISK")$(p_text 62%%)$(p_close)"
FMT1="#[align=left bg=$BG]${ROW2_L}#[align=right]${ROW2_R}"

# ── pane shell: byte-exact Starship clone (catppuccin_mocha), user = "dev" —
#    same segmented prompt as the rest of the plugin family ──
cat > "$WORK/rc.sh" <<'RC'
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export LANG=en_US.UTF-8
_SEP=$(printf '\xee\x82\xb0'); _CAPL=$(printf '\xee\x82\xb6'); _CAPR=$(printf '\xee\x82\xb4')
_APPLE=$(printf '\xef\x85\xb9'); _BRANCH=$(printf '\xef\x90\x98')
_CLOCKG=$(printf '\xef\x90\xba'); _ARROW=$(printf '\xef\x90\xb2')
_SURF0='49;50;68'; _PEACH='250;179;135'; _GREEN='166;227;161'; _TEAL='148;226;213'
_BLUE='137;180;250'; _PINK='245;194;231'; _TEXT='205;214;244'; _MANTLE='24;24;37'; _BASE='30;30;46'
_p10line() {
  local b git=""
  if b=$(git branch --show-current 2>/dev/null) && [ -n "$b" ]; then
    git=$(printf '\033[38;2;%s;48;2;%sm %s %s ' "$_BASE" "$_GREEN" "$_BRANCH" "$b")
  fi
  printf '\033[38;2;%sm%s\033[38;2;%s;48;2;%sm%s dev \033[38;2;%s;48;2;%sm%s\033[38;2;%s;48;2;%sm …/%s \033[38;2;%s;48;2;%sm%s%s\033[38;2;%s;48;2;%sm%s\033[38;2;%s;48;2;%sm%s\033[38;2;%s;48;2;%sm%s\033[38;2;%s;48;2;%sm %s %s \033[0m\033[38;2;%sm%s\033[0m \n' \
    "$_SURF0" "$_CAPL" "$_TEXT" "$_SURF0" "$_APPLE" "$_SURF0" "$_PEACH" "$_SEP" \
    "$_MANTLE" "$_PEACH" "${PWD##*/}" "$_PEACH" "$_GREEN" "$_SEP" "$git" \
    "$_GREEN" "$_TEAL" "$_SEP" "$_TEAL" "$_BLUE" "$_SEP" "$_BLUE" "$_PINK" "$_SEP" \
    "$_MANTLE" "$_PINK" "$_CLOCKG" "$(date '+%I:%M %p')" "$_PINK" "$_CAPR"
}
PROMPT_COMMAND=_p10line
PS1='\[\033[1;38;2;166;227;161m\]'"$_ARROW"'\[\033[0m\] '
RC

# ── staged sample project so the Starship prompt shows a …/path + branch pill ──
APP="$WORK/demo-app"
rm -rf "$APP"; mkdir -p "$APP/src"
printf '# demo-app\n\nA tiny sample project.\n' > "$APP/README.md"
printf 'flask\npytest\n' > "$APP/requirements.txt"
git -C "$APP" init -q -b main
git -C "$APP" -c user.name=dev -c user.email=dev@example.com add -A
git -C "$APP" -c user.name=dev -c user.email=dev@example.com commit -qm "initial commit"

# ── base theme (static parts; the format rows are set after server start) ──
cat > "$WORK/theme.conf" <<'CONF'
set -g default-terminal "tmux-256color"
set -as terminal-overrides ",xterm-256color:Tc"
set -g mouse on
setw -g automatic-rename off
set -g escape-time 0
set -g status 2
set -g status-interval 2
set -g status-style "bg=#1E1E1E,fg=#cdd6f4"
set -g status-left-length 30
set -g status-right-length 200
set -g window-status-separator ''
set -g pane-border-status top
set -g pane-border-format '#[align=centre]#{?pane_active,#[reverse],}#{pane_index}#[default] #{pane_current_command}'
set -g pane-border-style 'fg=#45475a'
set -g pane-active-border-style 'fg=#fab387,bold'
set -g message-style 'bg=#f9e2af,fg=#11111b,bold'
CONF

# ── isolated server: window 0 runs the clean shell EXPLICITLY (a session's first
#    window is created before default-command applies — classic prompt leak) ──
"$TMUX_BIN" -L "$SOCK" kill-server 2>/dev/null
sleep 0.3
"$TMUX_BIN" -L "$SOCK" -f "$WORK/theme.conf" new-session -d -s demo -x 118 -y 18 -n workspace -c "$APP" "bash --rcfile $WORK/rc.sh -i"
"$TMUX_BIN" -L "$SOCK" set -g default-command "bash --rcfile $WORK/rc.sh -i"

# cockpit rows (composed above with byte-escape glyphs)
"$TMUX_BIN" -L "$SOCK" set -g @pw-fmt "$WINF"
"$TMUX_BIN" -L "$SOCK" set -g @pw-cur "$WINCUR"
"$TMUX_BIN" -L "$SOCK" set -g 'status-format[0]' "$FMT0"
"$TMUX_BIN" -L "$SOCK" set -g 'status-format[1]' "$FMT1"

# ── llm-usage config, then load the plugin so it writes its sourced config
#    (provider + resolved jq path) into the cache dir that scripts/usage.sh reads.
#    Then warm the cache with a foreground __sync__ so the first on-camera render
#    already has the real quota string (redirected to /dev/null so run-shell never
#    echoes the value into the pane's copy-mode). ──
"$TMUX_BIN" -L "$SOCK" set -g @llm-usage-interval 2
"$TMUX_BIN" -L "$SOCK" set -g @llm-usage-provider "$PLUGIN/examples/static.sh"
"$TMUX_BIN" -L "$SOCK" run-shell "$PLUGIN/llm-usage.tmux"
"$TMUX_BIN" -L "$SOCK" run-shell "$USAGE __sync__ >/dev/null 2>&1"

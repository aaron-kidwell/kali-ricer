#!/usr/bin/env bash

[ -n "${BASH_VERSION:-}" ] || exec bash "$0" "$@"
set -uo pipefail

GTK_THEME="Catppuccin-Mocha-Blue-Standard+Default"
ICON_THEME="Papirus-Dark"
CURSOR_THEME="Bibata-Modern-Ice"; CURSOR_SIZE=24
UI_FONT="JetBrainsMono Nerd Font 10"; TITLE_FONT="JetBrainsMono Nerd Font Bold 10"
WALLPAPER="$HOME/Pictures/wall.png"
WALL_URL="https://w.wallhaven.cc/full/l3/wallhaven-l317d2.png"
CAT_URL="https://github.com/catppuccin/gtk/releases/download/v1.0.3/catppuccin-mocha-blue-standard+default.zip"
BG=0D0D0F FG=DFDEE6 CYAN=45C1DD BLUE=4545F5 MUTED=908EAA

LBIN="$HOME/.local/bin"; mkdir -p "$LBIN"
msg(){ printf '>> %s\n' "$*"; }
dl(){ curl -fL --retry 3 -A Mozilla/5.0 -o "$1" "$2" >/dev/null 2>&1; }
xq(){ xfconf-query -c "$1" -p "$2" -n -t "$3" -s "$4" 2>/dev/null || xfconf-query -c "$1" -p "$2" -s "$4"; }
apt_get(){ sudo DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a apt-get -y \
    -o Dpkg::Options::=--force-confold -o Dpkg::Options::=--force-confdef "$@"; }

[ "$(id -u)" = 0 ] && { echo "run as your user, not root"; exit 1; }
command -v xfconf-query >/dev/null || { echo "no xfconf-query — is this Xfce?"; exit 1; }
[ -n "${DISPLAY:-}" ] || { echo " run inside the Xfce desktop, not a TTY"; exit 1; }
sudo -v

apt_get install wmctrl xdotool >/dev/null 2>&1
INSTALLER_WIN=$(xdotool getactivewindow 2>/dev/null || true)

msg "updating system (apt update + upgrade) — can take a few minutes"
apt_get update || true
apt_get upgrade || true

msg "installing packages"
for p in papirus-icon-theme papirus-folders \
  xfce4-whiskermenu-plugin xfce4-pulseaudio-plugin xfce4-systemload-plugin \
  xfce4-clipman-plugin xfce4-notifyd xfce4-screenshooter xfce4-panel-profiles \
  xfce4-terminal plank conky-all thunar rofi \
  eza bat fd-find ripgrep fzf zoxide git-delta btop fastfetch tmux \
  neovim gcc make libnotify-bin wmctrl xdotool unzip curl fontconfig; do
    dpkg -s "$p" >/dev/null 2>&1 && continue
    apt_get install --no-install-recommends "$p" >/dev/null 2>&1 || msg "skip $p (unavailable)"
done

msg "fonts, cursor, theme, wallpaper"
fc-list 2>/dev/null | grep -qi "JetBrainsMono Nerd Font" || {
    d="$HOME/.local/share/fonts/JBMono"; mkdir -p "$d"; z=$(mktemp)
    dl "$z" https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip \
        && { unzip -o "$z" -d "$d" >/dev/null 2>&1; fc-cache -f "$d" >/dev/null 2>&1; } || msg "font download failed"
    rm -f "$z"; }
[ -d "$HOME/.local/share/icons/Bibata-Modern-Ice" ] || {
    t=$(mktemp); mkdir -p "$HOME/.local/share/icons"
    dl "$t" https://github.com/ful1e5/Bibata_Cursor/releases/latest/download/Bibata-Modern-Ice.tar.xz \
        && tar -xf "$t" -C "$HOME/.local/share/icons" >/dev/null 2>&1 || msg "cursor download failed"
    rm -f "$t"; }
mkdir -p "$HOME/.themes"
[ -d "$HOME/.themes/$GTK_THEME" ] || { z=$(mktemp); dl "$z" "$CAT_URL" && unzip -o "$z" -d "$HOME/.themes" >/dev/null 2>&1; rm -f "$z"; }

[ -d "$HOME/.themes/$GTK_THEME" ] || [ -d "/usr/share/themes/$GTK_THEME" ] || {
    f=$(ls -d "$HOME/.themes/"*[Cc]atppuccin*[Mm]ocha*[Bb]lue* 2>/dev/null | head -1)
    GTK_THEME=$([ -n "$f" ] && basename "$f" || echo Kali-Dark); }
has_buttons(){ ls "$1"/close-active.* >/dev/null 2>&1; }
WM_THEME="$GTK_THEME"
has_buttons "$HOME/.themes/$WM_THEME/xfwm4" || has_buttons "/usr/share/themes/$WM_THEME/xfwm4" || {
    WM_THEME=Kali-Dark; has_buttons /usr/share/themes/Kali-Dark/xfwm4 || WM_THEME=Default; }
mkdir -p "$HOME/Pictures"
[ -f "$WALLPAPER" ] || dl "$WALLPAPER" "$WALL_URL" || msg "wallpaper download failed"

msg "theme, icons, cursor, fonts, compositor"
xq xsettings /Net/ThemeName       string "$GTK_THEME"
xq xsettings /Net/IconThemeName   string "$ICON_THEME"
xq xsettings /Gtk/CursorThemeName string "$CURSOR_THEME"
xq xsettings /Gtk/CursorThemeSize int    "$CURSOR_SIZE"
xq xsettings /Gtk/FontName        string "$UI_FONT"
xq xsettings /Xft/Antialias int 1; xq xsettings /Xft/Hinting int 1
xq xsettings /Xft/HintStyle string hintslight; xq xsettings /Xft/RGBA string rgb
xq xfwm4 /general/theme         string "$WM_THEME"
xq xfwm4 /general/title_font    string "$TITLE_FONT"
xq xfwm4 /general/button_layout string "O|HMC"
xq xfwm4 /general/use_compositing bool true
for s in show_frame_shadow show_popup_shadow show_dock_shadow; do xq xfwm4 "/general/$s" bool false; done
xq xfwm4 /general/inactive_opacity int 90
xq xfce4-desktop /desktop-icons/style int 0
command -v papirus-folders >/dev/null && sudo papirus-folders -C blue --theme Papirus-Dark >/dev/null 2>&1

if [ -f "$WALLPAPER" ]; then
    props=$(xfconf-query -c xfce4-desktop -l 2>/dev/null | grep 'last-image$')
    if [ -n "$props" ]; then
        echo "$props" | while read -r p; do xfconf-query -c xfce4-desktop -p "$p" -s "$WALLPAPER"; done
    else
        mon=$(xrandr 2>/dev/null | awk '/ connected/{print $1;exit}'); mon=${mon:-Virtual-1}
        xfconf-query -c xfce4-desktop -p "/backdrop/screen0/monitor$mon/workspace0/last-image" -n -t string -s "$WALLPAPER" 2>/dev/null
    fi
    xfconf-query -c xfce4-desktop -l 2>/dev/null | grep 'image-style$' | while read -r p; do xfconf-query -c xfce4-desktop -p "$p" -s 5; done
fi

msg "keybinds"
ksc(){ xq xfce4-keyboard-shortcuts "/commands/custom/$1" string "$2"; }
ksc "<Super>Return" xfce4-terminal
ksc "<Super>e" thunar
ksc "<Super>space" "rofi -show drun"
ksc "Print" xfce4-screenshooter
wmk(){ xq xfce4-keyboard-shortcuts "/xfwm4/custom/$1" string "$2"; }
wmk "<Super><Shift>q" close_window_key
wmk "<Super>Left" tile_left_key;              wmk "<Super>Right" tile_right_key
wmk "<Super>Up" maximize_window_key;          wmk "<Super>Down" tile_down_key
wmk "<Super><Shift>Left" tile_up_left_key;    wmk "<Super><Shift>Right" tile_up_right_key
wmk "<Super><Control>Left" tile_down_left_key; wmk "<Super><Control>Right" tile_down_right_key
xq xfwm4 /general/tile_on_move bool true

msg "configs: terminal, nvim, conky, starship, shell"
mkdir -p "$HOME/.config/xfce4/terminal"
cat > "$HOME/.config/xfce4/terminal/terminalrc" <<EOF
[Configuration]
FontName=JetBrainsMono Nerd Font 11
ScrollingLines=10000
MiscBell=FALSE
MiscMenubarDefault=FALSE
MiscToolbarDefault=FALSE
BackgroundMode=TERMINAL_BACKGROUND_TRANSPARENT
BackgroundDarkness=0.88
ColorForeground=#$FG
ColorBackground=#$BG
ColorCursor=#$CYAN
ColorPalette=#333242;#903034;#014761;#8BB0C6;#$BLUE;#25516A;#$CYAN;#DAD8E3;#$MUTED;#D7878B;#33C6FC;#7DC0D3;#A2A2FA;#76AFCF;#A2E0EE;#ECEBF1
EOF

grep -q '^TerminalEmulator=' "$HOME/.config/xfce4/helpers.rc" 2>/dev/null \
    && sed -i 's/^TerminalEmulator=.*/TerminalEmulator=xfce4-terminal/' "$HOME/.config/xfce4/helpers.rc" \
    || echo 'TerminalEmulator=xfce4-terminal' >> "$HOME/.config/xfce4/helpers.rc"
sudo update-alternatives --set x-terminal-emulator /usr/bin/xfce4-terminal >/dev/null 2>&1

[ -d "$HOME/.config/nvim" ] || {
    git clone --depth=1 https://github.com/LazyVim/starter "$HOME/.config/nvim" >/dev/null 2>&1 && {
        rm -rf "$HOME/.config/nvim/.git"; mkdir -p "$HOME/.config/nvim/lua/plugins"
        cat > "$HOME/.config/nvim/lua/plugins/colorscheme.lua" <<'EOF'
return {
  { "catppuccin/nvim", name = "catppuccin", priority = 1000, opts = { flavour = "mocha" } },
  { "LazyVim/LazyVim", opts = { colorscheme = "catppuccin" } },
}
EOF
    }
}

mkdir -p "$HOME/.config/nvim/lua/plugins"
cat > "$HOME/.config/nvim/lua/plugins/yeti.lua" <<'YETI'
local hl_cmds = {
  [[syntax match ipaddr /\(\(25\_[0-5]\|2\_[0-4]\_[0-9]\|\_[1]\?\_[0-9]\?\_[0-9]\|\_[0]\)\.\)\{3\}\(25\_[0-5]\|2\_[0-4]\_[0-9]\|\_[1]\?\_[0-9]\?\_[0-9]\|\_[0]\)/]],
  [[highlight IPformat term=bold cterm=bold ctermfg=196 ctermbg=NONE gui=bold guifg=#ff0000 guibg=NONE]],
  [[highlight! link ipaddr IPformat]],
  [[syntax match macaddr /\(\(\_[0-9]\|\_[a-f]\|\_[A-F]\)\{2\}\(\:\)\)\{5\}\(\_[0-9]\|\_[a-f]\|\_[A-F]\)\{2\}/]],
  [[highlight MACformat term=bold cterm=bold ctermfg=DarkBlue ctermbg=NONE gui=bold guifg=Green guibg=NONE]],
  [[highlight! link macaddr MACformat]],
  [[syntax match ip6addr /\<\(\(\_[A-Fa-f0-9]\{1,4\}\:\)\{7\}\(\_[A-Fa-f0-9]\{1,4\}\)\{1\}\)\>/]],
  [[syntax match ip6addr /\<\(\(\_[A-Fa-f0-9]\{1,4\}\:\)\{0,7\}\(\:\_[A-Fa-f0-9]\{1,4\}\)\{0,7\}\)\>/]],
  [[syntax match ip6addr /\<\(\(\(\_[A-Fa-f0-9]\{1,4\}\:\)\{1,7\}\|\:\)\:\)\>/]],
  [[syntax match ip6addr /\<\(\:\(\:\_[A-Fa-f0-9]\{1,4\}\)\{1,7\}\)\>/]],
  [[highlight IP6format term=bold cterm=bold ctermfg=220 ctermbg=NONE gui=bold guifg=#ffd700 guibg=NONE]],
  [[highlight! link ip6addr IP6format]],
  [[syntax region xWarning start=/!!/ end=/$/]],
  [[highlight! link xWarning ErrorMsg]],
  [[syntax region xOptional start=/^?/ end=/$/]],
  [[highlight! link xOptional Special]],
  [[syntax region xWhackComment start="\(^\|\s\)//" end="$" keepend]],
  [[highlight! link xWhackComment Comment]],
  [[syntax region xBashComment start="^#" end="$" keepend]],
  [[highlight! link xBashComment Comment]],
  [[syntax match timestamp /\v<\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}Z?>/]],
  [[highlight Timeformat cterm=bold ctermfg=0 ctermbg=3 gui=bold guifg=black guibg=yellow]],
  [[highlight! link timestamp Timeformat]],
}
return {
  "LazyVim/LazyVim",
  init = function()
    local o = vim.opt
    o.tabstop = 4
    o.softtabstop = 4
    o.expandtab = true
    o.shiftwidth = 4
    o.cursorline = true
    o.wildmenu = true
    o.showmatch = true
    o.mouse = "a"
    o.clipboard = "unnamedplus"
    o.ignorecase = true
    o.incsearch = true
    o.hlsearch = true
    o.foldenable = true
    o.foldlevelstart = 0
    o.foldnestmax = 5
    o.foldmethod = "marker"
    o.foldmarker = "[[,]]"
    local map = vim.keymap.set
    map("x", "<LeftRelease>", '"*y', { silent = true, desc = "Yank drag-selection to clipboard" })
    map("n", "<MiddleMouse>", '"*p', { desc = "Paste primary" })
    map("v", "<MiddleMouse>", '"*p', { desc = "Paste primary" })
    map("i", "<MiddleMouse>", "<C-r>*", { desc = "Paste primary" })
    map("v", "<C-c>", '"*y', { desc = "Copy selection to primary" })
    map("v", "<C-y>", '"+y', { desc = "Copy selection to clipboard" })
    map("n", "<C-Up>", ":m-2<CR>", { silent = true, desc = "Move line up" })
    map("n", "<C-Down>", ":m+<CR>", { silent = true, desc = "Move line down" })
    map("n", "<leader>d", ":co .<CR>", { silent = true, desc = "Duplicate line" })
    map("n", "<PageUp>", "gt", { desc = "Next tab" })
    map("n", "<PageDown>", "gT", { desc = "Prev tab" })
    map("n", "<F12>", "za", { desc = "Toggle fold" })
    map("n", "<F5>", function()
      vim.api.nvim_put({ os.date("!%Y-%m-%dT%H:%M:%SZ") }, "c", true, true)
    end, { desc = "Insert ISO 8601 UTC timestamp" })
    map("i", "<F5>", function()
      vim.api.nvim_put({ os.date("!%Y-%m-%dT%H:%M:%SZ") }, "c", false, true)
    end, { desc = "Insert ISO 8601 UTC timestamp" })
    local grp = vim.api.nvim_create_augroup("YetiHighlights", { clear = true })
    local function apply()
      for _, c in ipairs(hl_cmds) do pcall(vim.cmd, c) end
    end
    vim.api.nvim_create_autocmd({ "BufWinEnter", "Syntax", "ColorScheme" }, { group = grp, callback = apply })
    apply()
  end,
}
YETI

cat > "$HOME/.conkyrc" <<EOF
conky.config = {
    alignment='top_right', background=true, update_interval=2.0, double_buffer=true,
    own_window=true, own_window_type='normal',
    own_window_hints='undecorated,below,sticky,skip_taskbar,skip_pager',
    own_window_argb_visual=true, own_window_argb_value=170, own_window_colour='$BG',
    border_inner_margin=14, gap_x=30, gap_y=50, minimum_width=250, use_xft=true,
    font='JetBrainsMono Nerd Font:size=10', default_color='$FG',
    color1='$CYAN', color2='$BLUE',
};
conky.text = [[
\${color1}\${font JetBrainsMono Nerd Font:bold:size=16}\${time %H:%M:%S}\${font}
\${color}\${time %A %d %B}   \${color1}UTC \${time %Y-%m-%dT%H:%M:%SZ}\${color}
\${color2}\${hr 1}\${color}
\${color1}󰇄\${color} \${nodename}    \${color1}󰌢\${color} \${kernel}
\${color1}󰅐\${color} up \${uptime_short}
\${color2}\${hr 1}\${color}
\${color1}\${color} CPU \${cpu}%   \${cpubar 6}
\${color1}\${color} RAM \${memperc}%   \${membar 6}
\${color1}󰋊\${color} /   \${fs_used_perc /}%   \${fs_bar 6 /}
\${color2}\${hr 1}\${color}
\${color1}󰩠\${color} \${addr eth0}
\${color1}󰇚\${color} \${downspeed eth0}   \${color1}󰕒\${color} \${upspeed eth0}
]]
EOF

command -v starship >/dev/null || curl -sS https://starship.rs/install.sh | sh -s -- -y -b "$LBIN" >/dev/null 2>&1
cat > "$HOME/.config/starship.toml" <<EOF
add_newline = true
format = "\$username\$time\$directory\$character"
[username]
show_always = true
format = "[\$user](\$style)@"
style_user = "#903034"
[time]
disabled = false
utc_time_offset = "0"
time_format = "%Y-%m-%dT%H:%M:%SZ"
format = "[\$time](\$style) "
style = "#$CYAN"
[directory]
truncation_length = 3
style = "#$BLUE"
[character]
success_symbol = "[❯](bold #$CYAN)"
error_symbol = "[❯](bold #903034)"
EOF

grep -q 'kali-rice:shell' "$HOME/.zshrc" 2>/dev/null || cat >> "$HOME/.zshrc" <<'EOF'
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
[ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ] && source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
[ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ] && source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
command -v zoxide >/dev/null && eval "$(zoxide init zsh)"
command -v eza    >/dev/null && alias ls='eza --group-directories-first --icons=auto'
command -v batcat >/dev/null && alias cat='batcat --paging=never'
command -v fdfind >/dev/null && ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd" 2>/dev/null
alias grep='grep --color=auto'
command -v nvim >/dev/null && { alias v='nvim'; export EDITOR=nvim; }
command -v starship  >/dev/null && eval "$(starship init zsh)"
command -v fastfetch >/dev/null && fastfetch
EOF

msg "configs: tmux, btop, bat, fastfetch, rofi"
cat > "$HOME/.tmux.conf" <<EOF
set -g mouse on
set -g base-index 1
setw -g pane-base-index 1
set -g renumber-windows on
set -g history-limit 20000
set -g escape-time 10
set -g default-terminal "tmux-256color"
set -ga terminal-overrides ",*256col*:Tc"
set -g status-position top
set -g status-style "bg=#$BG,fg=#$FG"
set -g status-left "#[bg=#$CYAN,fg=#$BG,bold] #S #[bg=#$BG,fg=#$CYAN]▓▒░"
set -g status-left-length 40
set -g status-right "#[fg=#$MUTED]#(date -u +%Y-%m-%dT%H:%M:%SZ) "
setw -g window-status-format "#[fg=#$MUTED] #I:#W "
setw -g window-status-current-format "#[bg=#$BLUE,fg=#ECEBF1,bold] #I:#W "
set -g pane-border-style "fg=#333242"
set -g pane-active-border-style "fg=#$CYAN"
set -g message-style "bg=#$CYAN,fg=#$BG"
bind r source-file ~/.tmux.conf \; display "reloaded"
EOF

mkdir -p "$HOME/.config/btop/themes"
dl "$HOME/.config/btop/themes/catppuccin_mocha.theme" https://github.com/catppuccin/btop/raw/main/themes/catppuccin_mocha.theme
BTOP_THEME=catppuccin_mocha; [ -s "$HOME/.config/btop/themes/catppuccin_mocha.theme" ] || BTOP_THEME=Default
cat > "$HOME/.config/btop/btop.conf" <<EOF
color_theme = "$BTOP_THEME"
theme_background = False
vim_keys = True
rounded_corners = True
update_ms = 2000
EOF

mkdir -p "$HOME/.config/bat/themes"
dl "$HOME/.config/bat/themes/Catppuccin Mocha.tmTheme" "https://github.com/catppuccin/bat/raw/main/themes/Catppuccin%20Mocha.tmTheme"
BAT=$(command -v batcat || command -v bat || true)
BAT_THEME="Catppuccin Mocha"
if [ -s "$HOME/.config/bat/themes/Catppuccin Mocha.tmTheme" ] && [ -n "$BAT" ]; then "$BAT" cache --build >/dev/null 2>&1; else BAT_THEME="ansi"; fi
cat > "$HOME/.config/bat/config" <<EOF
--theme="$BAT_THEME"
--style="numbers,changes,header"
EOF

mkdir -p "$HOME/.config/fastfetch"
cat > "$HOME/.config/fastfetch/config.jsonc" <<'EOF'
{
  "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
  "logo": { "source": "kali", "padding": { "top": 1 } },
  "display": { "separator": "  ", "color": { "keys": "blue" } },
  "modules": [
    "title", "separator",
    { "type": "os",       "key": "OS" },
    { "type": "kernel",   "key": "Kernel" },
    { "type": "uptime",   "key": "Uptime" },
    { "type": "packages", "key": "Packages" },
    { "type": "shell",    "key": "Shell" },
    { "type": "de",       "key": "DE" },
    { "type": "wm",       "key": "WM" },
    { "type": "terminal", "key": "Terminal" },
    "separator",
    { "type": "cpu",      "key": "CPU" },
    { "type": "gpu",      "key": "GPU" },
    { "type": "memory",   "key": "Memory" },
    { "type": "disk",     "key": "Disk" },
    { "type": "localip",  "key": "IP" }
  ]
}
EOF

mkdir -p "$HOME/.config/rofi"
cat > "$HOME/.config/rofi/config.rasi" <<'EOF'
configuration {
    modi: "drun,run,window";
    show-icons: true;
    icon-theme: "Papirus-Dark";
    font: "JetBrainsMono Nerd Font 11";
    drun-display-format: "{name}";
}
@theme "ado"
EOF
cat > "$HOME/.config/rofi/ado.rasi" <<EOF
* {
    bg:    #$BG;
    bg2:   #1a1a24;
    fg:    #$FG;
    cyan:  #$CYAN;
    blue:  #$BLUE;
    muted: #$MUTED;
    background-color: transparent;
    text-color: @fg;
}
window   { background-color: @bg; border: 2px; border-color: @cyan; border-radius: 8px; width: 45%; padding: 12px; }
inputbar { children: [ prompt, entry ]; padding: 8px; background-color: @bg2; border-radius: 6px; margin: 0 0 8px 0; }
prompt   { text-color: @cyan; padding: 0 8px 0 0; }
entry    { placeholder: "search…"; placeholder-color: @muted; }
listview { lines: 8; scrollbar: false; }
element  { padding: 8px; border-radius: 6px; }
element selected { background-color: @blue; text-color: #ECEBF1; }
element-icon { size: 1.2em; padding: 0 8px 0 0; }
element-text { vertical-align: 0.5; }
EOF

msg "panel"
xfce4-panel-profiles save "$HOME/panel-backup-$(date +%s).tar.bz2" >/dev/null 2>&1 || msg "panel backup failed (continuing)"
q(){ xfconf-query -c xfce4-panel "$@" >/dev/null 2>&1; }
q -p / -rR
q -p /panels -n -a -t int -s 1
q -p /panels/dark-mode -n -t bool -s true
q -p /panels/panel-1/position -n -t string -s "p=6;x=0;y=0"
q -p /panels/panel-1/length -n -t uint -s 100
q -p /panels/panel-1/size -n -t uint -s 30
q -p /panels/panel-1/background-style -n -t uint -s 1
q -p /panels/panel-1/background-rgba -n -a -t double -s 0 -t double -s 0 -t double -s 0 -t double -s 0

while IFS='|' read -r n name exec icon; do
    d="$HOME/.config/xfce4/panel/launcher-$n"; mkdir -p "$d"
    printf '[Desktop Entry]\nType=Application\nName=%s\nExec=%s\nIcon=%s\nTerminal=false\n' "$name" "$exec" "$icon" > "$d/app.desktop"
    q -p "/plugins/plugin-$n/items" -n -a -t string -s "app.desktop"
done <<'LAUNCH'
2|Terminal|xfce4-terminal|org.xfce.terminal
3|Files|thunar|system-file-manager
4|Burp Suite|burpsuite|kali-burpsuite
5|Neovim|xfce4-terminal --title=nvim -e nvim|nvim
LAUNCH

i=1; for pl in whiskermenu launcher launcher launcher launcher separator tasklist systemload pulseaudio notification-plugin clock actions; do
    q -p "/plugins/plugin-$i" -n -t string -s "$pl"; i=$((i+1))
done
q -p /plugins/plugin-6/expand -n -t bool -s true
q -p /plugins/plugin-6/style -n -t uint -s 0
q -p /plugins/plugin-11/mode -n -t uint -s 2
q -p /plugins/plugin-11/digital-time-format -n -t string -s "%a %d %b  %H:%M:%S"
ids=(); for n in $(seq 1 12); do ids+=(-t int -s "$n"); done
q -p /panels/panel-1/plugin-ids -n -a "${ids[@]}"

msg "autostart + layout"
mkdir -p "$HOME/.config/autostart"
mkauto(){ printf '[Desktop Entry]\nType=Application\nName=%s\nExec=%s\nX-XFCE-Autostart-enabled=true\n' "$1" "$2" > "$HOME/.config/autostart/$1.desktop"; }
mkauto plank plank; mkauto conky conky
pkill -f xpytile.py 2>/dev/null
rm -rf "$HOME/.local/share/xpytile" "$HOME/.config/autostart/xpytile.desktop" "$LBIN/tiling-toggle"

cat > "$LBIN/rice-welcome" <<'WELCOME'
#!/usr/bin/env bash
command -v wmctrl >/dev/null && command -v xdotool >/dev/null || exit 0
touch "$HOME/notes.txt" 2>/dev/null
open_term(){
    if [ -n "${1:-}" ]; then xfce4-terminal --disable-server --hide-menubar -e "bash -lc '$1'" >/dev/null 2>&1 &
    else xfce4-terminal --disable-server --hide-menubar >/dev/null 2>&1 & fi
    local pid=$! id="" i=0
    while [ -z "$id" ] && [ $i -lt 100 ]; do
        id=$(xdotool search --pid "$pid" --onlyvisible 2>/dev/null | head -1)
        [ -z "$id" ] && { sleep 0.1; i=$((i+1)); }
    done
    printf '%s' "$id"
}
snap(){ [ -n "$1" ] && { wmctrl -i -a "$1" 2>/dev/null; sleep 0.25; xdotool key --clearmodifiers "$2" 2>/dev/null; sleep 0.15; }; }
snap "$(open_term "")"                     "super+Left"
snap "$(open_term "nvim $HOME/notes.txt")" "super+shift+Right"
snap "$(open_term "btop")"                 "super+ctrl+Right"
WELCOME
chmod +x "$LBIN/rice-welcome"

xfce4-panel -r >/dev/null 2>&1 &
xfwm4 --replace >/dev/null 2>&1 &
sleep 1
pgrep -x plank >/dev/null || plank >/dev/null 2>&1 &
pkill -x conky 2>/dev/null; conky >/dev/null 2>&1 &

cat > "$HOME/rice-README.txt" <<'EOF'
Keys : Super+Return term · Super+E files · Super+Space rofi · Super+Shift+Q close · Print shot
Tile : Super+arrows halves · Super+Up max · Super+Shift/Ctrl+Left-Right quarters · or drag to an edge
Layout: run 'rice-welcome' (left shell · top-right notes · bottom-right btop)
Restore panel: xfce4-panel-profiles load ~/panel-backup-*.tar.bz2
EOF
msg "done (summary in ~/rice-README.txt)"
setsid "$LBIN/rice-welcome" >/dev/null 2>&1 &
sleep 2
[ -n "${INSTALLER_WIN:-}" ] && wmctrl -i -c "$INSTALLER_WIN" >/dev/null 2>&1
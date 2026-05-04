#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
#  accent-fix installer
#  Supports: niri, Hyprland, and other wlroots-based compositors
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

# ── If not in a terminal, reopen inside one ────────────────────
if [ ! -t 0 ]; then
    SELF="$(realpath "$0")"
    for term in kitty foot alacritty wezterm konsole gnome-terminal xterm; do
        if command -v "$term" &>/dev/null; then
            exec "$term" -- bash "$SELF"
        fi
    done
    notify-send "accent-fix" "No terminal found. Run from terminal." 2>/dev/null || true
    exit 1
fi

G="\e[32m"; Y="\e[33m"; B="\e[34m"; R="\e[31m"; N="\e[0m"; BOLD="\e[1m"
ok()   { echo -e "${G}✓${N} $*"; }
info() { echo -e "${B}→${N} $*"; }
warn() { echo -e "${Y}⚠${N} $*"; }
err()  { echo -e "${R}✗${N} $*"; }
hdr()  { echo -e "\n${BOLD}${B}── $* ──${N}"; }

echo -e "${BOLD}"
echo "  ╔══════════════════════════════════════╗"
echo "  ║      accent-fix  installer  v2.0     ║"
echo "  ║  PowerAccent for Wayland compositors ║"
echo "  ╚══════════════════════════════════════╝"
echo -e "${N}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
BIN="$BIN_DIR/accent_fix_daemon.py"
SVC_DIR="$HOME/.config/systemd/user"
SVC="$SVC_DIR/accent-fix.service"

# ════════════════════════════════════════════════════════════════
hdr "1/4  Dependencies"
# ════════════════════════════════════════════════════════════════
DEPS=(python-gobject gtk4 gtk4-layer-shell python-evdev wtype wl-clipboard)

# Detect package manager
PKG_CMD=""
if command -v paru &>/dev/null; then
    PKG_CMD="paru"
elif command -v yay &>/dev/null; then
    PKG_CMD="yay"
elif command -v pacman &>/dev/null; then
    PKG_CMD="sudo pacman"
else
    err "No supported package manager found (paru/yay/pacman)"
    exit 1
fi

MISSING=()
for pkg in "${DEPS[@]}"; do
    if ! pacman -Q "$pkg" &>/dev/null; then
        MISSING+=("$pkg")
    fi
done
if [ ${#MISSING[@]} -gt 0 ]; then
    info "Installing: ${MISSING[*]}"
    $PKG_CMD -S --needed --noconfirm "${MISSING[@]}"
else
    ok "All dependencies present"
fi

# ════════════════════════════════════════════════════════════════
hdr "2/4  Daemon"
# ════════════════════════════════════════════════════════════════
mkdir -p "$BIN_DIR"

if [ -f "$BIN" ]; then
    cp "$BIN" "${BIN}.bak"
    warn "Backup saved: ${BIN}.bak"
fi

cp "$SCRIPT_DIR/accent_fix_daemon.py" "$BIN"
chmod +x "$BIN"
ok "accent_fix_daemon.py installed to $BIN"

# ════════════════════════════════════════════════════════════════
hdr "3/4  Systemd service"
# ════════════════════════════════════════════════════════════════
mkdir -p "$SVC_DIR"

if [ -f "$SVC" ]; then
    cp "$SVC" "${SVC}.bak"
    warn "Backup saved: ${SVC}.bak"
fi

cp "$SCRIPT_DIR/accent-fix.service" "$SVC"

systemctl --user daemon-reload
systemctl --user enable --now accent-fix.service
ok "Service enabled and started"

# ════════════════════════════════════════════════════════════════
hdr "4/4  Hyprland keybinds (optional)"
# ════════════════════════════════════════════════════════════════
HYPR_KEYBINDS="$HOME/.config/hypr/custom/keybinds.conf"
HYPR_SNIPPET='
# === ACCENT-FIX SUBMAP ===
submap = accent_active
binde = , Right, exec, true
binde = , Left, exec, true
binde = , a, exec, true
binde = , e, exec, true
binde = , i, exec, true
binde = , o, exec, true
binde = , u, exec, true
binde = , y, exec, true
binde = , c, exec, true
binde = , n, exec, true
binde = , s, exec, true
binde = , z, exec, true
binde = , d, exec, true
binde = , f, exec, true
binde = , g, exec, true
binde = , h, exec, true
binde = , k, exec, true
binde = , l, exec, true
binde = , m, exec, true
binde = , p, exec, true
binde = , r, exec, true
binde = , t, exec, true
binde = , w, exec, true
binde = , x, exec, true
binde = , 0, exec, true
binde = , 1, exec, true
binde = , 2, exec, true
binde = , 3, exec, true
binde = , 4, exec, true
binde = , 5, exec, true
binde = , 6, exec, true
binde = , 7, exec, true
binde = , 8, exec, true
binde = , 9, exec, true
binde = , minus, exec, true
binde = , equal, exec, true
binde = , slash, exec, true
binde = , period, exec, true
binde = , comma, exec, true
binde = , apostrophe, exec, true
binde = , semicolon, exec, true
binde = , bracketleft, exec, true
binde = , bracketright, exec, true
binde = , backslash, exec, true
binde = , grave, exec, true
binde = , space, exec, true
submap = global
# === ACCENT-FIX SUBMAP END ==='

if [ -f "$HYPR_KEYBINDS" ]; then
    if grep -q "ACCENT-FIX SUBMAP" "$HYPR_KEYBINDS" 2>/dev/null; then
        ok "Hyprland keybinds already present — skipping"
    else
        cp "$HYPR_KEYBINDS" "${HYPR_KEYBINDS}.bak"
        echo "$HYPR_SNIPPET" >> "$HYPR_KEYBINDS"
        ok "Keybinds added to $HYPR_KEYBINDS"
    fi
else
    info "Hyprland keybinds file not found — skipping (not needed for niri)"
fi

# ════════════════════════════════════════════════════════════════
echo ""
echo -e "${BOLD}${G}  ✓ Installation complete!${N}"
echo ""
echo "  Service status:"
systemctl --user status accent-fix.service --no-pager -l 2>/dev/null | grep -E "Active|Main PID" | sed 's/^/    /' || true
echo ""
echo "  Useful commands:"
echo "    systemctl --user status accent-fix    # status"
echo "    systemctl --user restart accent-fix   # restart"
echo "    journalctl --user -u accent-fix -f    # live logs"
echo ""
read -rp "  Press Enter to close..."

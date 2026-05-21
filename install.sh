#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
#  accent-fix installer v3.0  —  robust edition
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

# ── If not in a terminal, reopen inside one ────────────────────
if [ ! -t 0 ]; then
    SELF="$(realpath "$0")"
    for term in kitty foot alacritty wezterm konsole gnome-terminal xterm; do
        if command -v "$term" &>/dev/null; then
            case "$term" in
                gnome-terminal) exec "$term" -- bash "$SELF" ;;
                konsole)        exec "$term" -e bash "$SELF" ;;
                *)              exec "$term" -- bash "$SELF" ;;
            esac
        fi
    done
    notify-send "accent-fix" "No terminal found. Run install.sh from a terminal." 2>/dev/null || true
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
echo "  ║      accent-fix  installer  v3.0     ║"
echo "  ║  PowerAccent for Wayland compositors ║"
echo "  ╚══════════════════════════════════════╝"
echo -e "${N}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
BIN="$BIN_DIR/accent_fix_daemon.py"
SVC_DIR="$HOME/.config/systemd/user"
SVC="$SVC_DIR/accent-fix.service"
NEEDS_RELOGIN=false

# ════════════════════════════════════════════════════════════════
hdr "1/6  Dependencies"
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
hdr "2/6  Input group check"
# ════════════════════════════════════════════════════════════════
# evdev needs read access to /dev/input/event* and write to /dev/uinput
if id -nG "$USER" | grep -qw input; then
    ok "User '$USER' is already in the 'input' group"
else
    warn "User '$USER' is NOT in the 'input' group"
    info "This is REQUIRED for accent-fix to read keyboard events"
    echo ""
    read -rp "  Add '$USER' to the 'input' group now? [Y/n] " ans
    ans="${ans:-y}"
    if [[ "$ans" =~ ^[Yy] ]]; then
        sudo usermod -aG input "$USER"
        ok "User added to 'input' group"
        NEEDS_RELOGIN=true
        warn "You MUST log out and log back in for this to take effect!"
    else
        err "Cannot continue without 'input' group membership"
        echo "  Run manually: sudo usermod -aG input $USER"
        exit 1
    fi
fi

# ════════════════════════════════════════════════════════════════
hdr "3/6  uinput access"
# ════════════════════════════════════════════════════════════════
# Ensure /dev/uinput is writable by the input group
UDEV_RULE="/etc/udev/rules.d/99-uinput-input.rules"
UDEV_CONTENT='KERNEL=="uinput", SUBSYSTEM=="misc", MODE="0660", GROUP="input", TAG+="uaccess"'

if [ -f "$UDEV_RULE" ] && grep -q 'uinput.*input' "$UDEV_RULE" 2>/dev/null; then
    ok "udev rule for /dev/uinput already present"
else
    info "Creating udev rule for /dev/uinput access"
    echo "$UDEV_CONTENT" | sudo tee "$UDEV_RULE" > /dev/null
    sudo udevadm control --reload-rules
    sudo udevadm trigger /dev/uinput 2>/dev/null || true
    ok "udev rule installed: $UDEV_RULE"
fi

# Also load the uinput module if not loaded
if ! lsmod | grep -q uinput; then
    sudo modprobe uinput 2>/dev/null || true
fi
# Ensure it loads on boot
if [ ! -f /etc/modules-load.d/uinput.conf ] || ! grep -q uinput /etc/modules-load.d/uinput.conf 2>/dev/null; then
    echo "uinput" | sudo tee /etc/modules-load.d/uinput.conf > /dev/null
    ok "uinput module set to load on boot"
fi

# ════════════════════════════════════════════════════════════════
hdr "4/6  Daemon"
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
hdr "5/6  Systemd service"
# ════════════════════════════════════════════════════════════════
mkdir -p "$SVC_DIR"

if [ -f "$SVC" ]; then
    cp "$SVC" "${SVC}.bak"
    warn "Backup saved: ${SVC}.bak"
fi

# Find gtk4-layer-shell .so dynamically
LAYER_SHELL_SO=""
for candidate in \
    /usr/lib/libgtk4-layer-shell.so \
    /usr/lib64/libgtk4-layer-shell.so \
    /usr/lib/libgtk4-layer-shell.so.0 \
    /usr/lib64/libgtk4-layer-shell.so.0 \
    /usr/lib/x86_64-linux-gnu/libgtk4-layer-shell.so; do
    if [ -f "$candidate" ]; then
        LAYER_SHELL_SO="$candidate"
        break
    fi
done

if [ -z "$LAYER_SHELL_SO" ]; then
    # Try ldconfig
    LAYER_SHELL_SO="$(ldconfig -p 2>/dev/null | grep libgtk4-layer-shell | head -1 | awk '{print $NF}')" || true
fi

if [ -z "$LAYER_SHELL_SO" ]; then
    warn "libgtk4-layer-shell.so not found! The overlay may not display correctly."
    warn "The daemon will still work but the accent popup might be tiled by your WM."
    LAYER_SHELL_SO="/usr/lib/libgtk4-layer-shell.so"
else
    ok "Found layer-shell at: $LAYER_SHELL_SO"
fi

# Determine the right systemd target
SYSTEMD_TARGET="graphical-session.target"
if ! systemctl --user list-unit-files "$SYSTEMD_TARGET" &>/dev/null; then
    SYSTEMD_TARGET="default.target"
    warn "graphical-session.target not found, using default.target"
fi

cat > "$SVC" << EOF
[Unit]
Description=Accent Fix — PowerAccent-style daemon for Wayland
After=$SYSTEMD_TARGET
PartOf=$SYSTEMD_TARGET

[Service]
Type=simple
Environment=LD_PRELOAD=$LAYER_SHELL_SO
Environment=GTK_USE_PORTAL=1
ExecStart=/usr/bin/env python3 %h/.local/bin/accent_fix_daemon.py
Restart=on-failure
RestartSec=5

[Install]
WantedBy=$SYSTEMD_TARGET
EOF

systemctl --user daemon-reload
systemctl --user enable --now accent-fix.service
ok "Service enabled and started"

# ════════════════════════════════════════════════════════════════
hdr "6/6  Verification"
# ════════════════════════════════════════════════════════════════
echo ""
FAIL=false

# Check service is running
if systemctl --user is-active accent-fix.service &>/dev/null; then
    ok "Service is running"
else
    err "Service failed to start!"
    echo "  Check logs: journalctl --user -u accent-fix -n 20 --no-pager"
    FAIL=true
fi

# Check evdev access
if python3 -c "
import evdev
devs = [evdev.InputDevice(p) for p in evdev.list_devices()]
kbds = [d for d in devs if 1 in d.capabilities() and 30 in d.capabilities().get(1,[])]
print(len(kbds))
" 2>/dev/null | grep -qv '^0$'; then
    ok "Can read keyboard devices via evdev"
else
    if $NEEDS_RELOGIN; then
        warn "Cannot read keyboard devices yet (log out and back in first!)"
    else
        err "Cannot read keyboard devices — check 'input' group membership"
        FAIL=true
    fi
fi

# Check uinput
if python3 -c "
import evdev, evdev.ecodes as ec
try:
    u = evdev.UInput({ec.EV_KEY: [ec.KEY_A]}, name='accent_fix_test')
    u.close()
    print('ok')
except: print('fail')
" 2>/dev/null | grep -q 'ok'; then
    ok "Can create UInput device (keystroke simulation works)"
else
    if $NEEDS_RELOGIN; then
        warn "UInput not accessible yet (log out and back in first!)"
    else
        err "Cannot create UInput device — check udev rules"
        FAIL=true
    fi
fi

echo ""
if $NEEDS_RELOGIN; then
    echo -e "${BOLD}${Y}  ⚠ IMPORTANT: You must LOG OUT and LOG BACK IN${N}"
    echo -e "${Y}    for group changes to take effect!${N}"
    echo ""
fi

if $FAIL; then
    echo -e "${BOLD}${Y}  ⚠ Installation completed with warnings${N}"
    echo "  Run the doctor script for diagnostics:"
    echo "    ./doctor.sh"
else
    echo -e "${BOLD}${G}  ✓ Installation complete!${N}"
fi
echo ""
echo "  Service status:"
systemctl --user status accent-fix.service --no-pager -l 2>/dev/null | grep -E "Active|Main PID" | sed 's/^/    /' || true
echo ""
echo "  Useful commands:"
echo "    systemctl --user status accent-fix    # status"
echo "    systemctl --user restart accent-fix   # restart"
echo "    journalctl --user -u accent-fix -f    # live logs"
echo "    ./doctor.sh                           # troubleshoot"
echo ""
read -rp "  Press Enter to close..."

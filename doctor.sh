#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
#  accent-fix doctor  —  diagnose installation issues
# ═══════════════════════════════════════════════════════════════
set -uo pipefail

G="\e[32m"; Y="\e[33m"; B="\e[34m"; R="\e[31m"; N="\e[0m"; BOLD="\e[1m"
ok()   { echo -e "  ${G}✓${N} $*"; }
warn() { echo -e "  ${Y}⚠${N} $*"; }
err()  { echo -e "  ${R}✗${N} $*"; }
hdr()  { echo -e "\n${BOLD}${B}── $* ──${N}"; }

ERRORS=0
WARNINGS=0

echo -e "${BOLD}"
echo "  ╔══════════════════════════════════════╗"
echo "  ║       accent-fix  doctor  v1.0       ║"
echo "  ║        Installation diagnostics      ║"
echo "  ╚══════════════════════════════════════╝"
echo -e "${N}"

# ── 1. Dependencies ─────────────────────────────────────────────
hdr "Dependencies"
DEPS=(python-gobject gtk4 gtk4-layer-shell python-evdev wtype wl-clipboard)
for pkg in "${DEPS[@]}"; do
    if pacman -Q "$pkg" &>/dev/null; then
        ok "$pkg installed"
    else
        err "$pkg NOT installed"
        ((ERRORS++))
    fi
done

# ── 2. Python imports ───────────────────────────────────────────
hdr "Python imports"
for mod in gi evdev; do
    if python3 -c "import $mod" 2>/dev/null; then
        ok "python3 can import '$mod'"
    else
        err "python3 CANNOT import '$mod'"
        ((ERRORS++))
    fi
done

if python3 -c "
import gi
gi.require_version('Gtk', '4.0')
from gi.repository import Gtk
" 2>/dev/null; then
    ok "GTK4 bindings working"
else
    err "GTK4 bindings FAILED"
    ((ERRORS++))
fi

if python3 -c "
import gi
gi.require_version('Gtk4LayerShell', '1.0')
from gi.repository import Gtk4LayerShell
" 2>/dev/null; then
    ok "gtk4-layer-shell bindings working"
else
    warn "gtk4-layer-shell bindings NOT working (overlay may not display)"
    echo "       Try: export LD_PRELOAD=/usr/lib/libgtk4-layer-shell.so"
    ((WARNINGS++))
fi

# ── 3. Input group ──────────────────────────────────────────────
hdr "Input group"
if id -nG "$USER" | grep -qw input; then
    ok "User '$USER' is in the 'input' group"
else
    err "User '$USER' is NOT in the 'input' group"
    echo "       Fix: sudo usermod -aG input $USER   (then log out/in)"
    ((ERRORS++))
fi

# ── 4. evdev device access ──────────────────────────────────────
hdr "Keyboard device access"
KBD_COUNT=$(python3 -c "
import evdev, evdev.ecodes as ec
devs = []
for p in evdev.list_devices():
    try:
        d = evdev.InputDevice(p)
        caps = d.capabilities()
        if ec.EV_KEY in caps and ec.KEY_A in caps.get(ec.EV_KEY, []):
            if ec.EV_REL not in caps:
                devs.append(d.name)
    except: pass
print(len(devs))
for n in devs: print(f'  - {n}')
" 2>/dev/null) || KBD_COUNT="0"

first_line=$(echo "$KBD_COUNT" | head -1)
if [ "$first_line" != "0" ] && [ -n "$first_line" ]; then
    ok "Found $first_line keyboard device(s):"
    echo "$KBD_COUNT" | tail -n +2
else
    err "NO keyboard devices accessible via evdev"
    echo "       This is usually a group permission issue."
    echo "       Check: ls -la /dev/input/event*"
    ((ERRORS++))
fi

# ── 5. uinput access ────────────────────────────────────────────
hdr "UInput access (/dev/uinput)"
if [ -e /dev/uinput ]; then
    ok "/dev/uinput exists"
    PERMS=$(ls -la /dev/uinput 2>/dev/null)
    echo "       $PERMS"
else
    err "/dev/uinput does not exist"
    echo "       Fix: sudo modprobe uinput"
    ((ERRORS++))
fi

UINPUT_TEST=$(python3 -c "
import evdev, evdev.ecodes as ec
try:
    u = evdev.UInput({ec.EV_KEY: [ec.KEY_A]}, name='accent_fix_test')
    u.close()
    print('ok')
except PermissionError:
    print('permission_denied')
except Exception as e:
    print(f'error: {e}')
" 2>/dev/null) || UINPUT_TEST="error"

if [ "$UINPUT_TEST" = "ok" ]; then
    ok "Can create UInput device"
elif [ "$UINPUT_TEST" = "permission_denied" ]; then
    err "Permission denied on /dev/uinput"
    echo "       Fix: Create udev rule:"
    echo '       echo '\''KERNEL=="uinput", SUBSYSTEM=="misc", MODE="0660", GROUP="input", TAG+="uaccess"'\'' | sudo tee /etc/udev/rules.d/99-uinput-input.rules'
    echo "       sudo udevadm control --reload-rules && sudo udevadm trigger /dev/uinput"
    ((ERRORS++))
else
    err "UInput test failed: $UINPUT_TEST"
    ((ERRORS++))
fi

# ── 6. Layer shell library ──────────────────────────────────────
hdr "gtk4-layer-shell library"
FOUND_SO=""
for candidate in \
    /usr/lib/libgtk4-layer-shell.so \
    /usr/lib64/libgtk4-layer-shell.so \
    /usr/lib/libgtk4-layer-shell.so.0 \
    /usr/lib64/libgtk4-layer-shell.so.0; do
    if [ -f "$candidate" ]; then
        FOUND_SO="$candidate"
        break
    fi
done
if [ -z "$FOUND_SO" ]; then
    FOUND_SO="$(ldconfig -p 2>/dev/null | grep libgtk4-layer-shell | head -1 | awk '{print $NF}')" || true
fi

if [ -n "$FOUND_SO" ]; then
    ok "Found at: $FOUND_SO"
else
    warn "libgtk4-layer-shell.so NOT found on system"
    echo "       The accent overlay may not display as a floating overlay."
    ((WARNINGS++))
fi

# ── 7. Service file ─────────────────────────────────────────────
hdr "Systemd service"
SVC_FILE="$HOME/.config/systemd/user/accent-fix.service"
if [ -f "$SVC_FILE" ]; then
    ok "Service file exists: $SVC_FILE"

    # Check LD_PRELOAD path in service
    SVC_PRELOAD=$(grep 'LD_PRELOAD=' "$SVC_FILE" 2>/dev/null | sed 's/.*LD_PRELOAD=//' || true)
    if [ -n "$SVC_PRELOAD" ] && [ -f "$SVC_PRELOAD" ]; then
        ok "LD_PRELOAD path is valid: $SVC_PRELOAD"
    elif [ -n "$SVC_PRELOAD" ]; then
        err "LD_PRELOAD points to missing file: $SVC_PRELOAD"
        if [ -n "$FOUND_SO" ]; then
            echo "       Correct path should be: $FOUND_SO"
            echo "       Fix: Re-run install.sh or edit $SVC_FILE"
        fi
        ((ERRORS++))
    fi
else
    err "Service file NOT found at $SVC_FILE"
    echo "       Fix: Re-run install.sh"
    ((ERRORS++))
fi

# ── 8. Daemon file ──────────────────────────────────────────────
hdr "Daemon script"
BIN="$HOME/.local/bin/accent_fix_daemon.py"
if [ -f "$BIN" ]; then
    ok "Daemon script exists: $BIN"
    if [ -x "$BIN" ]; then
        ok "Daemon is executable"
    else
        warn "Daemon is NOT executable"
        echo "       Fix: chmod +x $BIN"
        ((WARNINGS++))
    fi
else
    err "Daemon script NOT found: $BIN"
    echo "       Fix: Re-run install.sh"
    ((ERRORS++))
fi

# ── 9. Service status ───────────────────────────────────────────
hdr "Service status"
if systemctl --user is-enabled accent-fix.service &>/dev/null; then
    ok "Service is enabled (starts on login)"
else
    warn "Service is NOT enabled"
    echo "       Fix: systemctl --user enable accent-fix.service"
    ((WARNINGS++))
fi

if systemctl --user is-active accent-fix.service &>/dev/null; then
    ok "Service is currently RUNNING"
    PID=$(systemctl --user show accent-fix.service --property=MainPID --value 2>/dev/null)
    if [ -n "$PID" ] && [ "$PID" != "0" ]; then
        ok "Daemon PID: $PID"
    fi
else
    err "Service is NOT running"
    echo "       Recent logs:"
    journalctl --user -u accent-fix -n 10 --no-pager 2>/dev/null | sed 's/^/       /' || true
    ((ERRORS++))
fi

# ── 10. CLI tools ───────────────────────────────────────────────
hdr "CLI tools"
for tool in wtype wl-copy wl-paste; do
    if command -v "$tool" &>/dev/null; then
        ok "$tool found: $(command -v "$tool")"
    else
        err "$tool NOT found"
        ((ERRORS++))
    fi
done

# ── Summary ─────────────────────────────────────────────────────
echo ""
echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "  ${BOLD}${G}✓ All checks passed! accent-fix should work correctly.${N}"
elif [ $ERRORS -eq 0 ]; then
    echo -e "  ${BOLD}${Y}⚠ $WARNINGS warning(s), but no critical errors.${N}"
else
    echo -e "  ${BOLD}${R}✗ $ERRORS error(s) and $WARNINGS warning(s) found.${N}"
    echo -e "  ${R}  Fix the errors above and run this script again.${N}"
fi
echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

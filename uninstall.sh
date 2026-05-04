#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
#  accent-fix uninstaller
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

G="\e[32m"; Y="\e[33m"; B="\e[34m"; R="\e[31m"; N="\e[0m"; BOLD="\e[1m"
ok()   { echo -e "${G}✓${N} $*"; }
info() { echo -e "${B}→${N} $*"; }
warn() { echo -e "${Y}⚠${N} $*"; }

echo -e "${BOLD}"
echo "  ╔══════════════════════════════════════╗"
echo "  ║    accent-fix  uninstaller           ║"
echo "  ╚══════════════════════════════════════╝"
echo -e "${N}"

BIN="$HOME/.local/bin/accent_fix_daemon.py"
SVC="$HOME/.config/systemd/user/accent-fix.service"

# Stop and disable service
if systemctl --user is-active accent-fix.service &>/dev/null; then
    systemctl --user stop accent-fix.service
    ok "Service stopped"
fi

if systemctl --user is-enabled accent-fix.service &>/dev/null; then
    systemctl --user disable accent-fix.service
    ok "Service disabled"
fi

# Remove files
[ -f "$SVC" ] && rm "$SVC" && ok "Removed $SVC"
[ -f "$BIN" ] && rm "$BIN" && ok "Removed $BIN"
[ -f "${BIN}.bak" ] && rm "${BIN}.bak" && ok "Removed ${BIN}.bak"

systemctl --user daemon-reload

echo ""
echo -e "${BOLD}${G}  ✓ accent-fix uninstalled successfully${N}"
echo ""

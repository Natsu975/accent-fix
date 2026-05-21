# Maintainer: natsu
pkgname=accent-fix
pkgver=2.0.0
pkgrel=1
pkgdesc="PowerAccent-style accent character picker for Wayland (niri, Hyprland)"
arch=('any')
url="https://github.com/Natsu975/accent-fix"
license=('MIT')
depends=(
    'python'
    'python-gobject'
    'gtk4'
    'gtk4-layer-shell'
    'python-evdev'
    'wtype'
    'wl-clipboard'
)
source=("accent_fix_daemon.py"
        "accent-fix.service")
sha256sums=('SKIP' 'SKIP')

package() {
    install -Dm755 "$srcdir/accent_fix_daemon.py" \
        "$pkgdir/usr/lib/$pkgname/accent_fix_daemon.py"

    install -Dm644 "$srcdir/accent-fix.service" \
        "$pkgdir/usr/lib/systemd/user/accent-fix.service"
}

post_install() {
    echo ""
    echo "==> IMPORTANT: accent-fix requires the user to be in the 'input' group."
    echo "==> Run:  sudo usermod -aG input \$USER"
    echo "==> Then log out and log back in."
    echo ""
    echo "==> You may also need a udev rule for /dev/uinput:"
    echo '==> echo '\''KERNEL=="uinput", SUBSYSTEM=="misc", MODE="0660", GROUP="input", TAG+="uaccess"'\'' | sudo tee /etc/udev/rules.d/99-uinput-input.rules'
    echo ""
    echo "==> Enable the service:  systemctl --user enable --now accent-fix.service"
    echo "==> Diagnose issues:     ./doctor.sh"
    echo ""
}

# Maintainer: natsu
pkgname=accent-fix
pkgver=1.0.0
pkgrel=1
pkgdesc="PowerAccent-style accent character picker for Wayland (niri, Hyprland)"
arch=('any')
url="https://github.com/YOURUSERNAME/accent-fix"
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

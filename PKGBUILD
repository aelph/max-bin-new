# Maintainer: Alex Elph (форк AUR-пакета max-bin)
# Original maintainer: KUHTOXO https://aur.archlinux.org/account/kuhtoxo

pkgname=max-bin-new
pkgver=26.27.2.76730
pkgrel=1

pkgdesc="MAX messenger."
arch=("x86_64")
url='https://max.ru'
license=("custom:max")
categories=("network")

depends=("libxcb" "libxinerama" "libxcomposite" "xcb-util-wm" "xcb-util-cursor" "libva" "libxaw"  "libvdpau" "libnotify" "desktop-file-utils" "libxres")
optdepends=('gnome-keyring: Fixses startup in Gmome. Store passwords and encryption keys.' 'hicolor-icon-theme')
options=('!strip' '!debug')

_app_name="MAX"
_filename="${_app_name}-${pkgver}.rpm"

provides=("max")
conflicts=("max" "max-bin")

source_x86_64=("https://download.max.ru/linux/rpm/el/9/${arch}/${_filename}")

sha256sums_x86_64=('e851b1933c97decf0adf090801655d0457bb30e6cba171b315921f2c6964ef23')

package() {
    cp -a "${srcdir}/usr/"  "${pkgdir}/usr/"
    mkdir -p "${pkgdir}/usr/bin/"
    ln -sf "/usr/share/max/bin/max" "${pkgdir}/usr/bin/max"
}

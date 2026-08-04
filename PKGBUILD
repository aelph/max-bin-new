# Maintainer: Alex Elph (форк AUR-пакета max-bin)
# Original maintainer: KUHTOXO https://aur.archlinux.org/account/kuhtoxo

pkgname=max-bin-new
pkgver=26.25.0.75929
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

sha256sums_x86_64=('c7a0bbe365bc4af8183b9184d988209145d19d7a769f96b31af9c9208813ebb2')

package() {
    cp -a "${srcdir}/usr/"  "${pkgdir}/usr/"
    mkdir -p "${pkgdir}/usr/bin/"
    ln -sf "/usr/share/max/bin/max" "${pkgdir}/usr/bin/max"
}

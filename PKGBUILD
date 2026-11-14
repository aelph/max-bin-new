# Maintainer: Alex Elph (форк AUR-пакета max-bin)
# Original maintainer: KUHTOXO https://aur.archlinux.org/account/kuhtoxo

pkgname=max-bin-new
pkgver=26.40.2.83257
pkgrel=1

pkgdesc="MAX messenger."
arch=("x86_64")
url='https://max.ru'
license=("custom:max")
categories=("network")

depends=("ca-certificates" "glib2" "libxcb" "libxinerama" "libxcomposite" "libxss" "xcb-util-wm" "xcb-util-cursor" "xcb-util-keysyms" "libxkbcommon" "libva" "libxaw" "libvdpau" "libnotify" "gsettings-desktop-schemas" "libxres" "libglvnd")
optdepends=('gnome-keyring: Fixses startup in Gmome. Store passwords and encryption keys.' 'hicolor-icon-theme')
options=('!strip' '!debug')

_app_name="MAX"
_filename="${_app_name}-${pkgver}.rpm"

provides=("max")
conflicts=("max" "max-bin")

source_x86_64=("https://download.max.ru/linux/rpm/el/9/${arch}/${_filename}")

sha256sums_x86_64=('86cb9f13c4e2cd0996ffe314cf29ec86eda37765346b806ab3eaefe823ca9b72')

package() {
    cp -a "${srcdir}/usr/"  "${pkgdir}/usr/"
    mkdir -p "${pkgdir}/usr/bin/"
    ln -sf "/usr/share/max/bin/max" "${pkgdir}/usr/bin/max"

    # Встроенные библиотеки из EL9 перекрывают системные через RPATH ($ORIGIN/../lib64) и ломают max-service — процесс звонков. Системный libmount.so.1 требует LIBSYSTEMD_251, которого нет в libsystemd.so.0.23.0 из RPM, из-за чего сервис падает при старте и звонки не работают. Напрямую с ними в бандле никто не слинкован, они подтягиваются только транзитивно через системный glib.
    rm -f "${pkgdir}/usr/share/max/bin/max-service/lib64/libsystemd.so.0"*
    rm -f "${pkgdir}/usr/share/max/bin/max-service/lib64/libpcre2-8.so.0"*
}

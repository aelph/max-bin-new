#!/usr/bin/env bash
# Обновление пакета max-bin-new из официального RPM-репозитория MAX.
#
#   ./update.sh            — проверить, собрать, установить, закоммитить
#   ./update.sh check      — только проверить наличие новой версии
#   ./update.sh rollback   — показать локальные версии для отката
#   ./update.sh rollback <версия> — установить указанную локальную версию

set -euo pipefail
cd "$(dirname "$0")"

REPO_URL="https://download.max.ru/linux/rpm/el/9/x86_64"
PKGNAME="max-bin-new"

latest_version() {
    local primary
    primary=$(curl -fsSL "${REPO_URL}/repodata/repomd.xml" \
        | grep -oP '(?<=href=")repodata/[^"]*primary\.xml\.gz')
    curl -fsSL "${REPO_URL}/${primary}" | gunzip \
        | grep -oP '(?<=href="MAX-)[0-9][^"]*(?=\.rpm")' | sort -V | tail -1
}

current_version() {
    grep -oP '(?<=^pkgver=).*' PKGBUILD
}

cmd="${1:-update}"

case "$cmd" in
check)
    cur=$(current_version); new=$(latest_version)
    echo "Локальная версия:  $cur"
    echo "Версия в RPM-репо: $new"
    if [[ $(vercmp "$new" "$cur") -gt 0 ]]; then
        echo "Доступно обновление. Запустите: ./update.sh"
        exit 10
    else
        echo "Обновление не требуется."
    fi
    ;;

update)
    cur=$(current_version); new=$(latest_version)
    if [[ $(vercmp "$new" "$cur") -le 0 ]]; then
        echo "Уже актуальная версия: $cur"
        exit 0
    fi
    echo "Обновление $cur -> $new"
    sed -i -e "s/^pkgver=.*/pkgver=$new/" -e "s/^pkgrel=.*/pkgrel=1/" PKGBUILD
    updpkgsums
    makepkg -f
    makepkg --printsrcinfo > .SRCINFO
    git add PKGBUILD .SRCINFO
    git commit -m "Update $new"
    sudo pacman -U "${PKGNAME}-${new}-1-x86_64.pkg.tar.zst"
    echo "Готово: установлена версия $new."
    ;;

rollback)
    ver="${2:-}"
    if [[ -z "$ver" ]]; then
        echo "Локально доступные сборки:"
        ls -1 "${PKGNAME}"-*.pkg.tar.zst 2>/dev/null \
            | sed -E "s/^${PKGNAME}-(.+)-[0-9]+-x86_64.*/  \1/" \
            || echo "  (нет собранных пакетов)"
        echo
        echo "Откат: ./update.sh rollback <версия>"
        echo "Либо установка max-bin из AUR — он заместит ${PKGNAME} автоматически."
        exit 0
    fi
    pkgfile=$(ls -1 "${PKGNAME}-${ver}"-*-x86_64.pkg.tar.zst 2>/dev/null | head -1) || true
    if [[ -z "${pkgfile:-}" ]]; then
        echo "Сборка версии $ver не найдена." >&2
        exit 1
    fi
    sudo pacman -U "$pkgfile"
    ;;

*)
    echo "Использование: $0 [check|update|rollback [версия]]" >&2
    exit 2
    ;;
esac

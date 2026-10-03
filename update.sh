#!/usr/bin/env bash
# Обновление пакета max-bin-new из официального RPM-репозитория MAX.
#
#   ./update.sh            — проверить, собрать, установить, закоммитить
#   ./update.sh check      — только проверить наличие новой версии
#   ./update.sh notify     — тихая проверка с уведомлением на рабочий стол (для systemd-таймера)
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

# Версия в PKGBUILD: может опережать установленную, если коммит пришёл с другой машины.
current_version() {
    grep -oP '(?<=^pkgver=).*' PKGBUILD
}

# Установленная версия без pkgrel; пустая строка, если пакет не установлен.
installed_version() {
    { pacman -Q "$PKGNAME" 2>/dev/null || true; } | sed -E 's/^.* (.+)-[^-]+$/\1/'
}

cmd="${1:-update}"

case "$cmd" in
check)
    cur=$(installed_version); new=$(latest_version)
    echo "Установленная версия: ${cur:-не установлен}"
    echo "Версия в RPM-репо:    $new"
    if [[ $(vercmp "$new" "${cur:-0}") -gt 0 ]]; then
        echo "Доступно обновление. Запустите: ./update.sh"
        exit 10
    else
        echo "Обновление не требуется."
    fi
    ;;

notify)
    # Для systemd-таймера: молча выйти при недоступности сети,
    # показать уведомление только если вышла новая версия.
    cur=$(installed_version)
    new=$(latest_version) || exit 0
    [[ -n "$new" ]] || exit 0
    if [[ $(vercmp "$new" "${cur:-0}") -gt 0 ]]; then
        notify-send -a "MAX" -i max -u critical \
            "Вышло обновление MAX $new" \
            "Установлена версия ${cur:-не установлен}. Для обновления запустите: $(pwd)/update.sh"
    fi
    ;;

update)
    # Забрать коммиты с других машин, чтобы не создавать дублирующий «Update <версия>».
    git pull --ff-only
    cur=$(installed_version); new=$(latest_version)
    if [[ $(vercmp "$new" "${cur:-0}") -le 0 ]]; then
        echo "Уже актуальная версия: $cur"
        exit 0
    fi
    echo "Обновление ${cur:-не установлен} -> $new"
    if [[ $(current_version) != "$new" ]]; then
        sed -i -e "s/^pkgver=.*/pkgver=$new/" -e "s/^pkgrel=.*/pkgrel=1/" PKGBUILD
    fi
    updpkgsums
    makepkg -f
    makepkg --printsrcinfo > .SRCINFO
    git add PKGBUILD .SRCINFO
    # Если версия уже подтянута с другой машины, коммитить нечего.
    git diff --cached --quiet || git commit -m "Update $new"
    pkgrel=$(grep -oP '(?<=^pkgrel=).*' PKGBUILD)
    sudo pacman -U "${PKGNAME}-${new}-${pkgrel}-x86_64.pkg.tar.zst"
    # Отправить коммит сразу, чтобы другие машины подтянули его, а не создали свой.
    git push -q || echo "Предупреждение: git push не удался, выполните его вручную." >&2
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
    echo "Использование: $0 [check|notify|update|rollback [версия]]" >&2
    exit 2
    ;;
esac

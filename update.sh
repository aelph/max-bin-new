#!/usr/bin/env bash
# Обновление пакета max-bin-new из официального RPM-репозитория MAX.
#
#   ./update.sh            — проверить, собрать, установить, закоммитить
#   ./update.sh check      — только проверить наличие новой версии
#   ./update.sh notify     — тихая проверка с уведомлением на рабочий стол (для systemd-таймера)
#   ./update.sh rollback   — показать локальные версии для отката
#   ./update.sh rollback <версия> — установить указанную локальную версию
#
# Код возврата 11 у check и update — новая версия опубликована битой (см. release_ok).

set -euo pipefail
cd "$(dirname "$0")"

REPO_URL="https://download.max.ru/linux/rpm/el/9/x86_64"
PKGNAME="max-bin-new"

# Защита от битых релизов, общая для update.sh в yandex-music-pkg, max-bin и claude-desktop.
# 20.10.2026 Яндекс опубликовал Яндекс Музыку 5.124.1, чей deb весил 96 байт: в ar-архиве лежал только пустой индекс «__.SYMDEF SORTED», без control.tar и data.tar. Фид указывал именно этот размер и контрольную сумму именно этого файла, поэтому проверка суммы релиз пропустила, а сборка упала на распаковке.
# Настоящие сборки всех трёх программ весят десятки и сотни мегабайт, поэтому размер пакета из метаданных источника сверяется с порогом в 1 МиБ. Релиз меньше порога или без указанного размера считается битым: check и update сообщают о нём и выходят с кодом 11, notify молчит до тех пор, пока издатель не перевыпустит пакет.
MIN_SIZE=$((1024 * 1024))

release_ok() {
    [[ "${1:-}" =~ ^[0-9]+$ ]] && (( $1 >= MIN_SIZE ))
}

broken_release() {
    echo "Версия $1 опубликована битой (размер пакета: ${2:-не указан} байт), обновление пропущено." >&2
    exit 11
}

latest_entry() {
    # Выводит «версия размер» самой свежей версии. В primary.xml элемент <size package="…"> идёт внутри <package> раньше <location href="MAX-<версия>.rpm">.
    local primary
    primary=$(curl -fsSL "${REPO_URL}/repodata/repomd.xml" \
        | grep -oP '(?<=href=")repodata/[^"]*primary\.xml\.gz')
    curl -fsSL "${REPO_URL}/${primary}" | gunzip | awk '
        /<package / { s = "" }
        match($0, /<size package="[0-9]+"/) { s = substr($0, RSTART + 15, RLENGTH - 16) }
        match($0, /href="MAX-[0-9][^"]*\.rpm"/) { print substr($0, RSTART + 10, RLENGTH - 15), s }' \
        | sort -V -k1,1 | tail -1
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
    cur=$(installed_version); entry=$(latest_entry)
    read -r new size <<<"$entry"
    echo "Установленная версия: ${cur:-не установлен}"
    echo "Версия в RPM-репо:    $new"
    if [[ $(vercmp "$new" "${cur:-0}") -gt 0 ]]; then
        release_ok "$size" || broken_release "$new" "$size"
        echo "Доступно обновление. Запустите: ./update.sh"
        exit 10
    else
        echo "Обновление не требуется."
    fi
    ;;

notify)
    # Для systemd-таймера: молча выйти, если сеть так и не появилась,
    # показать уведомление только если вышла новая версия.
    # Persistent=true запускает пропущенную проверку сразу после загрузки,
    # когда сети может ещё не быть: повторять попытки до 5 минут.
    cur=$(installed_version)
    entry=""
    for _ in {1..10}; do
        entry=$(latest_entry 2>/dev/null) && [[ -n "$entry" ]] && break
        entry=""
        sleep 30
    done
    [[ -n "$entry" ]] || exit 0
    read -r new size <<<"$entry"
    # О битом релизе не уведомляем: обновиться на него всё равно нельзя.
    if [[ $(vercmp "$new" "${cur:-0}") -gt 0 ]] && release_ok "$size"; then
        notify-send -a "MAX" -i max -u critical \
            "Вышло обновление MAX $new" \
            "Установлена версия ${cur:-не установлен}. Для обновления запустите: $(pwd)/update.sh"
    fi
    ;;

update)
    # Забрать коммиты с других машин, чтобы не создавать дублирующий «Update <версия>».
    git pull --ff-only
    cur=$(installed_version); entry=$(latest_entry)
    read -r new size <<<"$entry"
    if [[ $(vercmp "$new" "${cur:-0}") -le 0 ]]; then
        echo "Уже актуальная версия: $cur"
        exit 0
    fi
    release_ok "$size" || broken_release "$new" "$size"
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

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## О репозитории

Локальный форк AUR-пакета `max-bin` под именем **`max-bin-new`**: переупаковка официального RPM мессенджера MAX (https://max.ru) для Arch Linux. В AUR пакет больше не публикуется: remote `upstream` указывает на `https://aur.archlinux.org/max-bin.git` только для чтения (push отключён — URL `DISABLED`). Никогда не пытаться делать push в AUR.

Отслеживаются только `PKGBUILD`, `.SRCINFO`, `update.sh`, `CLAUDE.md`, `.gitignore` — всё остальное (скачанный `.rpm`, собранные `.pkg.tar.zst`, каталоги `src/`, `pkg/`) игнорируется через whitelist в `.gitignore`. Собранные пакеты намеренно накапливаются в корне — они используются для отката.

## Обновление пакета

Всё делает `./update.sh`:

- `./update.sh check` — сравнить локальную версию с официальным RPM-репозиторием (`download.max.ru`, метаданные `repodata/`). Код возврата 10 — доступно обновление.
- `./update.sh` — если вышла новая версия: правит `pkgver` в `PKGBUILD`, `updpkgsums`, `makepkg -f`, перегенерация `.SRCINFO`, коммит `Update <pkgver>`, установка через `sudo pacman -U`.
- `./update.sh rollback [версия]` — откат на ранее собранную локальную версию; альтернатива — установить `max-bin` из AUR (пакеты взаимно конфликтуют и замещают друг друга).
- `./update.sh notify` — тихая проверка с уведомлением через `notify-send`; вызывается systemd-таймером пользователя `max-update-check.timer` (юниты в `~/.config/systemd/user/`, проверка ежедневная). При недоступности сети завершается молча.

Полный номер версии (`X.Y.Z.BUILD`) существует только в имени RPM-файла (`MAX-<версия>.rpm` в `location href` внутри `primary.xml.gz`); атрибут `ver` в метаданных содержит усечённую версию без номера сборки — не использовать его для сравнения.

## Особенности PKGBUILD

- Пакет бинарный: `package()` копирует `usr/` из распакованного RPM и создаёт симлинк `/usr/bin/max` → `/usr/share/max/bin/max`.
- `provides=("max")` и `conflicts=("max" "max-bin")` заданы жёстко (не через `${pkgname%-bin}` — с именем `max-bin-new` такая подстановка не работает). Не менять на вычисляемые.
- `options=('!strip' '!debug')` — бинарники не трогаем.
- Зависимости подобраны вручную под проприетарный бинарник (например, `libxres` нужен для звонков); после обновления версии проверять запуск приложения — могут появиться новые недостающие библиотеки.

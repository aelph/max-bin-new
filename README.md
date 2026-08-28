# max-bin-new

**Русская версия: [ПРОЧТИ.md](ПРОЧТИ.md)**

A local (not published to AUR) Arch Linux package for the **MAX** messenger (https://max.ru).
A fork of the AUR package [max-bin](https://aur.archlinux.org/packages/max-bin) with update automation and **a fix for broken audio/video calls**.

This is a binary package: the official EL9 RPM is repackaged as-is, without rebuilding.

## Audio and video calls do not work with the AUR package

If you installed MAX from the AUR package `max-bin` (or straight from the RPM) and calls silently fail while voice and video *messages* record and send just fine — this is why.

Calls are handled by a separate process, `/usr/share/max/bin/max-service/bin/max-service`, and on Arch it dies the moment it starts:

```
$ /usr/share/max/bin/max-service/bin/max-service
libsystemd.so.0: version `LIBSYSTEMD_251' not found (required by /usr/lib/libmount.so.1)
```

The RPM bundles `libsystemd.so.0.23.0` from EL9 in `bin/max-service/lib64/`, and `max-service` carries `RPATH $ORIGIN:$ORIGIN/../lib64` — so the bundled copy shadows the system one. At the same time the system `libglib-2.0.so.0` pulls in the system `libmount.so.1`, which needs the symbol version `LIBSYSTEMD_251` that the EL9 copy does not provide. Every Arch install is affected, because `util-linux` here is always built against current systemd.

Recording and sending voice/video messages keeps working because that runs inside the main `max` process, which has no bundled `libsystemd` — which is exactly why the breakage is easy to miss.

**The fix**, applied by this package in `package()`, is to drop the bundled copies so the system libraries are used:

```bash
rm -f "${pkgdir}/usr/share/max/bin/max-service/lib64/libsystemd.so.0"*
rm -f "${pkgdir}/usr/share/max/bin/max-service/lib64/libpcre2-8.so.0"*
```

Nothing in the bundle links against `libsystemd` directly (checked with `readelf -d`) — it is only pulled in transitively through the system glib, so removing it is safe. The bundled `libpcre2-8.so.0` is the same class of problem: it makes the system glib print `no version information available`. With both gone, `max-service` starts cleanly and calls work.

The fix is not tied to any particular version, so it survives updates. To verify after an update, run `max-service` by hand — a healthy start prints `RPC port: <number>` and the settings paths, with no `not found` lines.

## Usage

Everything is driven by a single script:

| Command | What it does |
|---|---|
| `./update.sh check` | Compares the local version against the official RPM repository. Exit code `10` means an update is available. |
| `./update.sh` | Full cycle: bumps `pkgver` in `PKGBUILD` → `updpkgsums` → `makepkg -f` → regenerates `.SRCINFO` → commits `Update <version>` → `sudo pacman -U`. |
| `./update.sh notify` | Silent check with a desktop notification (`notify-send`). Used by the systemd timer. |
| `./update.sh rollback` | Lists locally kept builds. |
| `./update.sh rollback <version>` | Rolls back to the given build (`sudo pacman -U`). |

### Automatic update notifications

The units `max-update-check.service` and `max-update-check.timer` live in `~/.config/systemd/user/`
(**outside this repository** — copy them separately when moving to another machine).
The timer fires daily at 12:00 (plus a random delay of up to an hour) — during the day, so the
notification is not missed overnight; `Persistent=true` means a check missed while the machine
was off runs on the next boot. The notification is sent with `critical` urgency: it stays on
screen until dismissed.

```
systemctl --user list-timers max-update-check.timer   # timer status
systemctl --user start max-update-check.service       # run a check manually
```

The timer never installs anything by itself — you only get a notification; then run `./update.sh`.

## Rollback

- **To a previous local build:** built `.pkg.tar.zst` files intentionally accumulate in the repository root — `./update.sh rollback <version>`.
- **To the AUR version:** install `max-bin` from AUR. The packages declare a mutual conflict (`conflicts`), so pacman replaces one with the other cleanly. Going back: `sudo pacman -U max-bin-new-<version>-*.pkg.tar.zst`.

## Caveats

- **Unofficial package.** A proprietary binary repackaged with no warranty of any kind; the MAX developers are not affiliated with this repository.
- **`sudo` at the end of an update.** `./update.sh` asks for a password during installation — run it in an interactive terminal. In a non-interactive environment everything except the install succeeds and `pacman -U` fails; install the package manually in that case.
- **Bandwidth and disk space.** Each update downloads a ~325 MB RPM; old builds (~400 MB each) are kept for rollback — prune them periodically.
- **A git commit is made automatically** on every update (`Update <version>`), before installation. If the install step fails, the commit already exists — that is fine: the files match the built package.
- **The `upstream` remote (AUR) is read-only.** Push is disabled (URL `DISABLED`). Do not `git pull upstream master` — the histories have diverged and `PKGBUILD`/`.SRCINFO` will conflict. Instead: `git fetch upstream`, inspect `git diff master upstream/master -- PKGBUILD`, and port useful changes by hand.
- **Never run `git reset --hard upstream/master`** — that is the one scenario that would wipe `update.sh` and the other local files.
- **`.gitignore` is a whitelist:** everything is ignored except files listed explicitly. To track a new file, first add a `!filename` line.
- **The version number** (`X.Y.Z.BUILD`) is parsed from RPM file names in the repository metadata; the `ver` attribute there is truncated and unusable for comparison.
- **Dependencies were picked by hand** for a closed-source binary (e.g. `libxres` is required for calls). After major updates, verify that the application starts and calls work — new libraries may be needed.
- **Check `max-service` after an update.** Calls live in a separate process, so launching the main application proves nothing about them. If a new RPM ships another bundled library that shadows a system one, add it to the `rm -f` list in `package()`. To find such conflicts across the whole package: `cd /usr/share/max && find . -type f \( -name '*.so*' -o -perm -u+x \) -exec sh -c 'ldd "$1" 2>&1 | grep -q "not found" && echo "$1"' _ {} \;`
- **`notify` stays silent when the network is down** — by design, to avoid false notifications.
- **MAX for Linux has no built-in self-updater:** on native RPM systems updates arrive via the dnf repository. This script is the Arch equivalent of that mechanism.

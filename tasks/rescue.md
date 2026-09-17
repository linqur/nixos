# rescue.efi — самодостаточный live-UKI для ремонта

Статус: **отложено, не нужен.** Решено 2026-10-26: если `last-good.efi` не помогает — ремонт с установочной флешки NixOS (процедура в Readme, «Восстановление»). Проработка ниже сохранена на случай, если флешки под рукой не окажется слишком часто.

Плата за отказ: нужна флешка с ISO, и на время ремонта выключается Secure Boot (не забыть включить обратно, проверить `sbctl status`). Данных и ключей rescue не спасал бы: ключи SB лежат на зашифрованном корне, при их потере — переустановка с выключенным SB в любом случае.

## Назначение
Минимальная NixOS в одном подписанном UKI на ESP (`EFI/rescue.efi`), выбирается вручную через «загрузку из файла» при включённом SB. Ничего не делает сама: LUKS и mount — руками. Даёт консоль, сеть и инструменты, чтобы поправить файлы на диске «сверху» или через chroot и собрать новое поколение.

## Решения
1. **Сценарий:** корень открывается, ключи `/var/lib/sbctl` живы; нужно поправить конфиг или `/etc` и собрать новое поколение по сети. Ключи потеряны → переустановка, вне задачи rescue.
2. **Сборка поколения — оба пути:** `nixos-enter --root /mnt` → `nixos-rebuild boot` (nix и git с диска) и `nixos-install --root /mnt --flake … --no-root-passwd` (nix из rescue в store диска; загрузчик ставится из нового поколения, uki-install подписывает ключами диска). Свой nix в rescue обязателен.
3. **Размер — один UKI ≤ 200 МБ**, ESP остаётся 1 ГБ. Большой UKI (B) и маленький UKI + образ на отдельном разделе с dm-verity (C) отклонены: обязательный набор и так влезает, разовое — `nix shell nixpkgs#…` по сети.
4. **Состав:** cryptsetup, e2fsprogs, dosfstools, gptfdisk, util-linux, iproute2, iwd, curl, git-minimal, nix, nixos-enter, nixos-install (без остального `nixos-install-tools`: nixos-generate-config тянет perl), helix, tmux, smartmontools, nvme-cli, systemd, coreutils, less, procps, findutils, grep, sed, kmod. Не берём: sbctl (подпись из chroot), openssh, testdisk, rsync (`cp -a` хватает), htop, strace, efibootmgr, pciutils, usbutils (при пропаже записи NVRAM firmware сама грузит `\EFI\BOOT\BOOTX64.EFI`).
5. **Редактор — helix-unwrapped** (≈6.5 МБ сжатым) с вашими настройками (тема nord, хоткеи, вид), **без грамматик** (−185 МБ). Альтернативы замерены: mg ~0.1, ne ~0.2, vis ~0.5, kakoune ~1–1.5, nano ~3, micro ~4 МБ сжатыми — экономия против helix ≤ 6 МБ не стоит смены хоткеев.
6. **Обновление — никогда автоматически.** Собирается и пишется один раз в `install.sh`; `switch`/`boot` rescue не трогают. Ключи меняются только при переустановке, а она пересобирает rescue — подпись не устаревает. gcroot не нужен: после записи файл самодостаточен.
7. **Ручная перезапись — `uki-install rescue <файл>`:** тот же `flock`; `ukify inspect` (`.linux`, `.initrd`, `.cmdline`, `.osrel`); отказ на уже подписанном файле; дальше общий путь записи: место → `.tmp` → fsync → sbverify с носителя → rename, до 3 попыток. Типичный вызов: `nix build .#rescue && uki-install rescue result/rescue.efi`.
8. **Один общий `.#rescue` на все хосты:** модули и прошивки — объединение под virtio и ROG. В VM проверяется тот же файл, что поедет на ноутбук. Ядро — `linuxPackages_latest` того же nixpkgs, что у системы на момент установки.
9. **Вход — автологин root на tty1**, без пароля: данные под LUKS, ключей SB в rescue нет; забытый пароль сделал бы rescue бесполезным. Консоль — `nixos/console.nix` (`ter-v24n`, цвета).
10. **Сеть — networkd + iwd стартуют сами:** DHCP по кабелю и USB-модему автоматически, Wi-Fi — `iwctl station wlan0 connect <SSID>`. NetworkManager отклонён: +133 МБ распакованно.
11. **install.sh:** после `nixos-install` → `nix build --store /mnt .#rescue` → `nixos-enter --root /mnt -c "uki-install rescue <путь>"` → `sbctl verify` (видит и rescue) → enroll. Ошибка шагов rescue — установка продолжается, предупреждение с командой ручной записи последней строкой вывода.
12. **UKI собирает Nix:** `.#rescue` — готовый неподписанный `rescue.efi` (тот же `pkgs.systemdUkify`). `init=` в cmdline указывает на toplevel внутри его же squashfs — цикла нет, т.к. сам UKI в toplevel не входит. Подписывает только `uki-install`.
13. **Лимит 200 МБ — предупреждение при сборке** `.#rescue` с разбивкой по крупнейшим путям, сборка не падает.
14. **Настройки helix — общий `lib/helix.nix`**, его импортируют `home-manager/modules/helix.nix` и rescue (`/root/.config/helix/config.toml`).
15. **Раскладка:** `rescue/configuration.nix` (состав, сеть, автологин, модули, прошивки; импортирует `nixos/kernel.nix`, `nixos/console.nix`), `rescue/build.nix` (squashfs без дублей + ukify, предупреждение о размере); flake — `packages.x86_64-linux.rescue`.

## ESP
Худший случай: BOOTX64 + `.tmp` + last-good (57×3) + rescue + `.tmp` (190×2) ≈ 550 МБ из 1 ГБ.

## Прототип и замеры (2026-10-26, nixpkgs 26.05, ядро 7.2.10)
База — `nixos/modules/installer/netboot/netboot.nix` (store в squashfs внутри initrd, overlay с tmpfs) + `profiles/minimal.nix`. Загрузка в VM **не проверялась**, только сборка.

| Итерация | closure | squashfs | UKI (ядро 14 + initrd) |
|---|---|---|---|
| r1: в лоб | 1.3 ГБ | 462 МБ | ≈500 МБ |
| r3: урезано | 588 МБ | 185 МБ | ≈221 МБ |
| r3 без копий ядра и stage-1 initrd в squashfs | — | 147 МБ | ≈183 МБ |

С tmux, smartmontools, nvme-cli — оценка ≈186 МБ.

Что срезано:
- **Модули ядра** 149 → ≈3 МБ: `makeModulesClosure` по списку (nvme, dm_crypt, xts, aesni_intel, algif_*, ext4, vfat, nls_*, squashfs, overlay, loop, efivarfs, xhci_pci, usb_storage, uas, sd_mod, usbhid, hid_generic, hid_asus, i2c_hid_acpi, atkbd, evdev, iwlwifi, iwlmvm, iwlmld, r8169, igc, cdc_ether, rndis_host, cdc_ncm, af_packet + модули stage-1 + autofs) и `modules.{order,builtin,builtin.modinfo}` из ядра. В `system.modulesTree` через `mkForce`; `boot.initrd.includeDefaultModules = false`, иначе stage-1 ищет ahci и прочее. Для VM добавить virtio_*.
- **Прошивки:** только `iwlwifi-gl-*` (BE200, 9 МБ). Нужна ещё `rtl_nic/rtl8125*` — модель проводной карты не проверена (`lspci -k`).
- **perl:** профиль `perlless` (etc overlay, userborn, systemd-initrd).
- **python:** `system.disableInstallerTools = true`, в пакеты — `pkgs.nixos-enter` и `config.system.build.nixos-install`.
- `nix.enable = false` (без nix-daemon, root работает со store напрямую; `/etc/nix/nix.conf` руками: flakes, `build-users-group =`) — уходит openssh из юнита демона. `systemd.suppressedSystemUnits` importd — уходит gnupg. `programs.nano.enable = false` (libmagic), документация, firewall, lvm.
- **Сжатие squashfs:** `xz -Xdict-size 100% -b 1M -Xbcj x86` — 147 МБ против 164 у zstd-22.
- **Дубли:** toplevel ссылается на ядро и stage-1 initrd, стандартный `make-squashfs` кладёт их в образ (≈38 МБ). Свой squashfs из closure без этих двух путей; ссылки `kernel`/`initrd` в toplevel повиснут — после загрузки не нужны.

Осталось крупным: systemd 60 + systemd-minimal 21, git-minimal 53 + gettext 24, icu 39 + boost 15 (зависимости nix), glibc 34, helix 28 МБ (распакованно).

## Приёмка (если вернёмся)
VM (OVMF secboot):
- [ ] `nix build .#rescue`, размер ≤ 200 МБ или предупреждение с разбивкой
- [ ] `install.sh`: rescue.efi до `sbctl verify`, подписан; сломанный шаг rescue → установка до конца, предупреждение последней строкой
- [ ] SB on → Boot From File → shell root без пароля, `ter-v24n`
- [ ] virtio-net по DHCP сам, `curl`, DNS
- [ ] ремонт: `cryptsetup open` → mount `/`, `/boot` → правка helix (тема, `C-s`) → `nixos-install --root /mnt --flake … --no-root-passwd` → новое поколение подписано, грузится
- [ ] то же через `nixos-enter` → `nixos-rebuild boot`
- [ ] `git clone` по https, tmux, `smartctl`, `nvme`
- [ ] `uki-install rescue`: перезапись, обрыв между `.tmp` и rename, отказ на подписанном
- [ ] `switch` и `nix-collect-garbage -d` rescue.efi не трогают, после GC грузится

Железо (ROG):
- [ ] Boot From File при SB
- [ ] клавиатура (hid_asus / i2c_hid / atkbd)
- [ ] Wi-Fi BE200 через `iwctl`
- [ ] проводная: чип и прошивка, DHCP
- [ ] USB-модем с телефона
- [ ] внутренний NVMe и USB-SSD, LUKS открывается

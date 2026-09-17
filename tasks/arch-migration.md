# Перенос с Arch: запланировано к установке/настройке

Статус: в работе, пункты разбираются по одному. Здесь только то, что есть в Arch и ещё не настроено в Nix. Замены (niri вместо Hyprland, fuzzel вместо wofi, helix, VS Code и т.д.) сюда не входят.

Отладочные утилиты, нужные пару раз в год, в конфиг не берём: `nix shell nixpkgs#<пакет>`, потом их убирает очередная чистка.

В репозитории нет `hardware-configuration.nix`, а `hosts/home-rog/disko.nix` содержит заглушку `device = "X"`.

## Железо
- [x] NVIDIA (RTX 5060 Max-Q): `hardware.nvidia` с open-модулем, `videoDrivers`, `modesetting` — [nvidia.nix](../nixos/nvidia.nix)
- [x] PRIME offload (Intel основная, NVIDIA по запросу)
- [ ] 32-бит и OpenCL (lib32-nvidia-utils, opencl-nvidia); `hardware.graphics.enable32Bit` уже есть
- [x] ~~nvidia-settings, nvtop~~: в конфиг не берём, nvtop разово
- [x] ~~`services.asusd` (asusctl)~~: отклонено, sysfs через ядро — [power.md](power.md)
- [x] ~~`services.supergfxd` (supergfxctl)~~: отклонено, гибрид + RTD3 — [power.md](power.md)
- [x] `hardware.cpu.intel.updateMicrocode` (intel-ucode) — [hardware.nix](../nixos/hardware.nix)
- [x] `hardware.enableRedistributableFirmware` (linux-firmware, sof-firmware)
- [ ] intel-undervolt (на 14-м поколении может быть заблокирован), cpupower — [cpu.md](cpu.md)
- [x] ~~brightnessctl, nvme-cli, evtest, stress~~: яркость делает `wosd`, остальное разово
- [x] ~~`services.ratbagd` + piper~~: настройки в памяти мыши; новую мышь — разово
- [x] ~~efibootmgr, dosfstools, ntfsprogs~~: `mkfs.vfat` уже есть, остальное разово
- [ ] btrfs: корень на btrfs в Arch; проверить `disko.nix`, `boot.supportedFilesystems`, btrfs-progs — для `home-rog`
- [ ] `hardware-configuration.nix` после установки на реальное железо — для `home-rog`

## Сеть и VPN
- [x] ~~sing-box~~: не нужен
- [x] ~~wireguard-tools~~: туннелей нет
- [x] ~~bind (dig), mtr, iw, pciutils, usbutils, smartmontools~~: отладочные, разово
- [ ] dnsmasq: проверить, нужен ли (у VM сеть через passt)
- [x] ~~localsend~~: браузерная версия
- [x] ~~android-file-transfer~~: не нужен
- [x] ~~remmina, freerdp~~: пока не нужны

## Приложения и утилиты
- [ ] discord: нужен, с оптимизацией — обсудить
- [x] ~~grim, slurp, swappy~~: хватает `screenshot` niri
- [x] ~~hyprsunset: аналога в niri нет~~: wlsunset не работал с niri (gamma control failed), написан свой wgamma ([scripts/src/wgamma](../scripts/src/wgamma)), автозапуск в [niri.nix](../home-manager/modules/niri.nix)
- [x] ~~wl-clipboard~~: буфер между окнами — протокол, его реализует niri; CLI-клиент нужен только helix
- [x] микшер: wiremix (TUI, запуск из терминала): громкость, mute, default; запоминает WirePlumber (`~/.local/state/wireplumber/`). Проверить, что default из `d` переживает ребут
- [ ] системный шумодав микрофона: DeepFilterNet в filter-chain PipeWire, умный фильтр WirePlumber на микрофоне по умолчанию — [denoise.nix](../nixos/denoise.nix); проверить на железе
- [x] архиватор: ouch (распаковка всего частого вкл. rar и 7z, упаковка zip/tar.*), экзотика (iso, msi) — 7-Zip разово; в Thunar — свои действия «Распаковать» / «Упаковать в zip» через ouch в окне foot ([thunar.nix](../home-manager/modules/thunar.nix)), плагин и GUI-архиватор не нужны; xdg-utils и less уже есть; ~~unrar, cdrtools~~ разово
- [x] Thunar: вид, панели, тулбар, скрытые файлы, ISO-даты и т.д. в xfconf — [thunar.nix](../home-manager/modules/thunar.nix); tumbler нужен и для миниатюр, и для Image Preview
- [x] ~~монтирование дисков в Thunar (udisks2, gvfs)~~: сервисы не включаем; диски — `sudo mount`
- [x] удаление сразу навсегда: Thunar — Del на delete в `accels.scm` ([thunar.nix](../home-manager/modules/thunar.nix)), VS Code — `files.enableTrash: false`. Корзины нет совсем: на месте `~/.local/share/Trash` файл из store ([no-trash.nix](../home-manager/modules/no-trash.nix)), «в корзину» в любом приложении падает с ошибкой, файл остаётся
- [x] btop — [packages.nix](../home-manager/packages.nix)
- [x] ~~qt5-wayland~~: приложений на Qt5 нет; вернуться, если появится
- [x] ~~ventoy-bin, woeusb-ng~~: разово

## Игры и Wine
Steam уже работает в `gamesjail` (см. [steam.md](steam.md)), mangohud подключён.
- [ ] wine
- [ ] portproton
- [ ] protontricks
- [ ] steamtinkerlaunch
- [ ] gamemode
- [ ] gamescope
- [ ] innoextract

Вопросы:
- запускать всё через обёртку `game` в `gamesjail` или отдельно;
- gamemode и gamescope внутри FHS-окружения Steam (`extraPkgs`) или системно.

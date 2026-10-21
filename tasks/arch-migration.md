# Перенос с Arch: запланировано к установке/настройке

Статус: не начато. Здесь только то, что есть в Arch и ещё не настроено в Nix. Замены (niri вместо Hyprland, fuzzel вместо wofi, helix, VS Code и т.д.) сюда не входят.

В репозитории нет `hardware-configuration.nix`, а `hosts/home-rog/disko.nix` содержит заглушку `device = "X"`.

## Железо
- [ ] NVIDIA (RTX 5060 Max-Q): `hardware.nvidia` с open-модулем, `videoDrivers`, `modesetting`
- [ ] PRIME offload (Intel основная, NVIDIA по запросу)
- [ ] 32-бит и OpenCL (lib32-nvidia-utils, opencl-nvidia); `hardware.graphics.enable32Bit` уже есть
- [ ] nvidia-settings, nvtop
- [ ] `services.asusd` (asusctl): профили платформы, подсветка; связать с [cpu.md](cpu.md)
- [ ] `services.supergfxd` (supergfxctl): переключение GPU
- [ ] `hardware.cpu.intel.updateMicrocode` (intel-ucode)
- [ ] `hardware.enableRedistributableFirmware` (linux-firmware, sof-firmware)
- [ ] intel-undervolt (на 14-м поколении может быть заблокирован), cpupower
- [ ] brightnessctl, nvme-cli, evtest, stress
- [ ] `services.ratbagd` + piper (мышь)
- [ ] efibootmgr, dosfstools, ntfsprogs
- [ ] btrfs: корень на btrfs в Arch; проверить `disko.nix`, `boot.supportedFilesystems`, btrfs-progs
- [ ] `hardware-configuration.nix` после установки на реальное железо

## Сеть и VPN
- [ ] sing-box
- [ ] wireguard-tools
- [ ] bind (dig), mtr, iw
- [ ] dnsmasq: проверить, нужен ли (у VM сеть через passt)
- [ ] localsend (нужен порт в фаерволе)
- [ ] android-file-transfer
- [ ] remmina, freerdp

## Приложения и утилиты
- [ ] discord
- [ ] grim, slurp, swappy: проверить, хватает ли встроенного `screenshot` niri
- [ ] hyprsunset: аналога в niri нет (wlsunset, gammastep)
- [ ] wl-clipboard (сейчас только зависимость helix)
- [ ] easyeffects, pavucontrol
- [ ] xdg-utils, unzip, unrar, less, cdrtools
- [ ] btop (в Nix сейчас htop)
- [ ] qt5-wayland: проверить, покрыто ли `qt.nix`
- [ ] ventoy-bin, woeusb-ng

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

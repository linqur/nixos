# Установка на железо: внешний SSD (home-rog-usb-hp)

Статус: в работе. Модули адаптируются по одному файлу: сначала предложение готовым кодом, после согласования — правка.

## Цель
NixOS на внешнем диске загружается на ROG Strix G18 и пригодна для работы: экран, Wi-Fi, звук, NVIDIA без тонкой настройки. Конфиг `vm` продолжает собираться. Внутренний NVMe (`home-rog`) — заготовка, не подключена.

## Железо
- Диск: HP Portable SSD P500 120 ГБ, SATA за мостом USB 3.1 Gen1 (`uas`), `/dev/disk/by-id/ata-HP_Portable_SSD_P500_HBSC111301000375`. Сейчас на нём Windows 11 — стирается целиком.
- TRIM через мост не проходит (`discard_max_bytes = 0`) — discard-опции не используем.
- Встроенный NVMe за Intel VMD (`10000:e1:00.0`) — для `home-rog` нужен `vmd` в initrd.
- CPU i7-14650HX, iGPU Raptor Lake-S (`PCI:0:2:0`), dGPU RTX 5060 Mobile, Blackwell (`PCI:1:0:0`) — только открытые модули.
- Wi-Fi Intel BE200 (`iwlwifi`, нужна прошивка), звук Intel HDA.
- Экран `eDP-2` (имя в Arch), 2560x1600@240. MUX в гибридном режиме. Secure Boot выключен (setup mode).

## Решения
1. **Отличия хостов — через `profile.nix`** (см. «Хосты и профили» в Readme.md). Поля добавляются по мере адаптации модулей.
2. **Хосты:** `vm`, `home-rog-usb-hp` (сейчас), `home-rog` (заготовка под NVMe, в flake не подключён).
3. **Загрузчик на внешнем диске:** `canTouchEfiVariables = false`, грузимся через запасной `\EFI\BOOT\BOOTX64.EFI` из меню загрузки (F8/Esc). NVRAM ноутбука и загрузка Arch не меняются.
4. **NVIDIA сразу, без глубоких настроек:** открытый модуль, `modesetting`, PRIME offload, `finegrained` (иначе dGPU не засыпает). Драйвер `latest`. Тонкая настройка (MUX, VRR, suspend) — отдельно.
5. **Установка с live ISO NixOS** (как в VM): `install.sh` рассчитан на него (`nixos-install`, `nixos-enter`). Перед сборкой новые файлы — в git (`git add`), иначе flake их не видит.

## Отложено
- ASUS (`asusd`/`supergfxd` или sysfs через `asus_armoury`): профиль питания, порог заряда — если без этого система работает.
- Bluetooth.
- Тонкая настройка NVIDIA, CPU — [cpu.md](cpu.md), остальное — [arch-migration.md](arch-migration.md).
- Suspend: с корнем на USB не полагаемся, проверить отдельно.

## План (по одному файлу)
- [x] `flake.nix`: `mkHost`, `profile` в `specialArgs` и Home Manager
- [x] `lib/enums.nix`, `hosts/vm/profile.nix`: новые поля по мере надобности
- [x] `nixos/initrd.nix`: модули по `storage` (usb / nvme+vmd / virtio)
- [x] `nixos/loader.nix`: `canTouchEfiVariables` по `storage`
- [x] `nixos/hardware.nix` (новый): микрокод, прошивки, qemu-guest/spice для VM
- [x] `nixos/nvidia.nix` (новый): драйвер по `gpu`
- [x] `home-manager/modules/niri.nix`: выход экрана из профиля
- [x] `hosts/vm/configuration.nix`: убрать то, что переехало в модули
- [x] `hosts/home-rog-usb-hp/`: `profile.nix`, `disko.nix` (by-id, без discard), `configuration.nix`
- [ ] `hosts/home-rog/`: профиль под NVMe — после доводки железа на `home-rog-usb-hp`
- [ ] сборка `.#vm` и `.#home-rog-usb-hp` без ошибок
- [ ] установка на диск

## Приёмка на железе
- [ ] загрузка с внешнего диска через меню F8, ввод пароля LUKS с клавиатуры ноутбука
- [ ] niri: 240 Гц, масштаб 1.3; имя панели из `niri msg outputs` — в `display.name` профиля
- [ ] Wi-Fi, звук
- [ ] `nvidia-smi` видит карту, `nvidia-offload glxinfo | grep renderer` — NVIDIA
- [ ] без нагрузки dGPU не греет ноутбук (температура, `nvidia-smi` power)
- [ ] `.#vm` по-прежнему собирается и загружается

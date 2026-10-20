# QEMU/KVM: виртуальные машины

Статус: модуль `nixos/virt.nix` применён, приёмка пройдена; осталась установка Windows 11 (отложено: мало места на тестовой системе).

## Задачи
- Windows 11 десктоп, Linux-десктопы, headless-серверы, проверка своего NixOS-конфига.
- Сеть: VM видят интернет, хост ходит в VM по проброшенным портам. VM друг друга не видят.
- GPU passthrough не нужен.

## Решения
1. **libvirt в session-режиме под отдельным пользователем `virtdev`.**
   - QEMU работает не от linqur: при побеге из гостя дом недоступен. Плюс `ProtectHome=yes` на сервисе.
   - Нет root-демона, polkit и setuid-обёрток libvirt.
   - Тот же паттерн, что `dockdev` у Docker.
2. **Ленивый старт без linger.** Системный `virtdev-qemud.socket` → `virtqemud --timeout 120` от `virtdev`.
   - Демон завершается через 2 минуты после последней VM. `virtlogd` и `virtstoraged` поднимаются им сами, тоже с таймаутом.
   - Системный, а не user-юнит: не нужен user manager на загрузке, есть системная D-Bus.
3. **Доступ linqur — прямо к сокету через группу `virtshare`, без прокси.**
   - virt-manager получает экран VM файловым дескриптором через сокет libvirt (`virDomainOpenGraphicsFD`), `systemd-socket-proxyd` такое не передаёт.
   - Session-демон не проверяет uid клиента, `auth_unix_rw = none`; доступ решают права сокета `0660`.
   - URI `qemu:///session?socket=…` без `+unix`: с явным транспортом virt-manager считает хост удалённым и отказывается открывать экран через FD.
4. **Стабильные пути через `/etc/profiles/per-user/virtdev`.** libvirt пишет пути к эмулятору и прошивке в XML VM; путь в `/nix/store` сломал бы VM после обновления и GC. Дескрипторы прошивок и virtiofsd пересобираются с этим путём.
5. **Сеть — passt** (`<interface type='user'><backend type='passt'/>`). Без root, без моста и dnsmasq.
6. **Выключение хоста.** Демон слушает `PrepareForShutdown` от logind: штатное выключение гостей (до 60 с), затем poweroff. Сохранение RAM на диск выключено (износ NVMe), автоподъём после загрузки выключен.

## Отклонено
- **`virtualisation.libvirtd`** (NixOS-модуль): libvirtd и libvirt-guests на каждой загрузке, по умолчанию QEMU от root, монолитный демон, обязательный polkit.
- **Session под linqur:** QEMU с правами на весь дом.
- **Incus:** постоянный демон для парков VM/контейнеров, избыточно.
- **GNOME Boxes:** тянет GNOME-стек.
- **Мост virbr0 / LAN-bridge:** только system-режим, VM друг друга видеть не должны.

## Как пользоваться
- virt-manager подключается сам (dconf), `virsh` работает без `-c` (`LIBVIRT_DEFAULT_URI`).
- Общий каталог `/srv/virt` (ссылка `~/virt`): ISO в `iso/`. Наследуемые ACL дают rwx linqur и virtdev.
- `/srv/virt/share` — для virtiofs: наследуемый rwx для всех (`d:o::rwx`), туда пишут и гостевые пользователи (uid 300000+).
- Диски — пул `default` в `/var/lib/virtdev/.local/share/libvirt/images` (создаёт virt-manager).
- Рекомендуемые настройки VM:
  - диск virtio, qcow2: `discard='unmap' detect_zeroes='unmap' cache='none' io='io_uring'`;
  - CPU `host-passthrough`;
  - `<memballoon model='virtio' freePageReporting='on'/>`;
  - экран: SPICE `listen type='none'` + `<gl enable='yes'/>`, видео virtio с `accel3d='yes'` (virgl); virt-manager по умолчанию ставит TCP 127.0.0.1 без GL;
  - в госте `qemu-guest-agent`: без него штатное выключение идёт через ACPI (кнопка питания), а Xfce по умолчанию показывает диалог выбора — при выключении хоста гость получит poweroff через 60 с. Без агента: в Xfce кнопка питания → «Выключить» (`xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/power-button-action -n -t int -s 4`);
  - правка готовой VM без ручного XML: `virt-xml <vm> --edit --network backend.type=passt,…`, применяется после полного выключения VM;
  - сеть: в virt-manager «Usermode networking», затем в XML `<backend type='passt'/>`;
  - проброс порта: `<portForward proto='tcp' address='127.0.0.1'><range start='2222' to='22'/></portForward>`. Без `address` passt слушает `0.0.0.0` (снаружи закрывает фаервол).
- Windows 11: firmware UEFI (Secure Boot), TPM 2.0 эмулятор, ISO `virtio-win` для драйверов.
- Проверка NixOS-конфига: `nixos-rebuild build-vm --flake .#vm` — без libvirt.

## Ограничения
- В прошивке QEMU нет ключей Microsoft: Secure Boot «поддерживается», но не включён. Windows 11 ставится; если понадобится включённый — `OVMFFull`.
- virtiofs: гостевой root = `virtdev`, остальные uid — диапазон 300000+. Гостевые пользователи (uid 1000 → 301000) в ACL не перечислены, поэтому шарить `/srv/virt/share` (rwx для всех). `cp` извне сужает маску ACL до прав исходника, `mv` извне ACL не даёт. `/srv/projects` — отдельное решение (группа devshare + `ReadWritePaths`).
- USB-проброс через SPICE требует setuid-помощника (`virtualisation.spiceUSBRedirection`), не включён.

## Проверено вне системы (session-демон от linqur в scratchpad)
UEFI Secure Boot + swtpm, passt с пробросом порта, qcow2 с discard, пул хранения (virtstoraged автозапуск), virtiofs (нужен `/run/wrappers` в PATH для newuidmap).

## Приёмка после switch
- [x] `systemctl status virtdev-qemud.socket` слушает, сервис неактивен
- [x] после перелогина `id` содержит `virtshare`; `virsh list --all` поднимает демон
- [x] virt-manager: Linux-гость, экран SPICE открывается
- [x] virgl (Linux-гость, `gl enable='yes'`)
- [ ] Windows 11: установка с TPM + UEFI (отложено: мало места на тестовой системе)
- [x] ssh в гостя через проброшенный порт
- [x] демон и `virtlogd`/`virtstoraged` завершаются через ~2 мин без VM
- [x] выключение хоста с запущенной VM: демон ловит `PrepareForShutdown` и держит остановку до D-Bus; гостю уходит запрос на выключение, через 60 с — poweroff. Live Xfce без агента показал диалог выбора и получил poweroff; с qemu-guest-agent `virsh shutdown` — 5 с
- [x] `ProtectHome`: из сервиса `/home/linqur` не виден

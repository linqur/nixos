# Загрузка через UKI вместо systemd-boot

Статус: код написан (установщик, `loader.nix`, `install.sh`, профиль, Readme), проверен в mount namespace; ждёт приёмки в VM. Обкатка — в VM, затем на `home-rog-usb-hp`.

## Цель
На каждый `switch`/`boot` собирать UKI, подписывать своими ключами sbctl и класть в `BOOTX64.EFI`. Без systemd-boot, без меню. Откат конфигурации — через git (сборка старого коммита), UKI на ESP нужны только для восстановления: последнее успешно загрузившееся поколение хранится отдельно и выбирается вручную через «загрузку из файла» в UEFI.

## Раскладка ESP
```
EFI/BOOT/BOOTX64.EFI  — последнее установленное (default)
EFI/last-good.efi     — последнее успешно загрузившееся (good)
```
Плюс временные `BOOTX64.EFI.tmp`, `last-good.efi.tmp` на время записи. Максимум ≈ 170 МБ (UKI ≈ 57 МБ: ядро 14 + initrd 43), ESP 1 ГБ. `rescue.efi` не делаем — `tasks/rescue.md`.
Установщик владеет только этими путями. Остатки systemd-boot на стенде не трогаем — стенд будет переустановлен.

## Состояние
Только gcroot'ы, номеров поколений и файлов-меток нет:
```
/nix/var/nix/gcroots/uki/default → toplevel в BOOTX64.EFI
/nix/var/nix/gcroots/uki/good    → toplevel в last-good.efi
```
gcroot — встроенный механизм Nix: GC не удаляет ничего, достижимого из `/nix/var/nix/gcroots/`. Поэтому `nix-collect-garbage -d` не ломает ни BOOTX64, ни last-good: UKI не самодостаточен, ему нужен toplevel из `init=` в cmdline.

## Решения
1. **Сборка при установке, не в Nix.** `boot.uki` из nixpkgs не подходит: cmdline содержит `init=${toplevel}/init` → цикл. Ключи в store класть нельзя, подпись всё равно при установке. Каждое поколение даёт новый UKI (путь toplevel в cmdline); ребилд без изменений нового поколения не создаёт.
2. **Вход установщика — `$toplevel/boot.json`** (bootspec). Секция `io.github.linqur.uki` из `loader.nix`: пути к ukify, stub, sbctl, os-release, `efiSysMountPoint`. Подключение — `boot.loader.external`.
3. **Состав UKI:** kernel, initrd (микрокод Intel уже внутри через `boot.initrd.prepend`), cmdline `init=… + kernelParams`, `.osrel`. Specialisations в bootspec — ошибка.
4. **Установка (`uki-install <toplevel>`, при `switch`/`boot`/`nixos-install`):**
   1. `flock /run/uki-install.lock`.
   2. Разбор хвостов прошлого обрыва:
      - `default.tmp` есть, `BOOTX64.EFI.tmp` нет → rename BOOTX64 прошёл: довести, rename `default.tmp` → `default`;
      - оба есть → обрыв до rename: удалить оба;
      - только `BOOTX64.EFI.tmp` → удалить.
   3. Быстрая оценка места до сборки: ядро + initrd нового поколения (размеры из bootspec, `stat`) + 1 МБ на stub/секции. Не хватает → выход, ESP не тронут.
   4. tmpfs (`/run`): `ukify build` → `ukify inspect` (секции на месте) → `sbctl sign` → проверка подписи.
   5. Точная проверка места по реальному размеру подписанного UKI. Не хватает → выход.
   6. Копия в `BOOTX64.EFI.tmp` → fsync → `posix_fadvise DONTNEED` → проверка подписи с носителя. До 3 попыток, перед каждой `.tmp` удаляется.
   7. gcroot `default.tmp` → новый toplevel.
   8. rename `BOOTX64.EFI.tmp` → `BOOTX64.EFI` (без ретрая) → fsync каталога.
   9. rename `default.tmp` → `default`.
5. **Отметка good (`uki-install mark-good`):** oneshot `WantedBy=multi-user.target`, `After=multi-user.target`, `Requisite=multi-user.target`, `RequiresMountsFor` ESP. `Requisite` обязателен: `After=` — только порядок, без него юнит запускается и после упавшего `multi-user.target`. `boot-complete.target` не годится: без условий он сразу после `sysinit.target` (вариант на будущее, когда появятся проверки здоровья: упорядочить его после `multi-user.target` и подключать проверки к нему через `Requires=` + `Before=`).
   1. `flock`. Если `/run/booted-system` ≠ `default` или `default` = `good` → ничего не делать (загрузка из last-good, обрыв перед п.4.9, или уже отмечено). Ошибка в безопасную сторону.
   2. если остался `last-good.efi.tmp`, то удалить его и gcroot `good.tmp` если тоже существует. Если `last-good.efi.tmp` не существует, но существует `good.tmp` значит юки успел переименоватьтся и нужно good.tmp переименовать в good как п.7 
   3. Проверить место по размеру `BOOTX64.EFI` (известен сразу).
   4. Копия `BOOTX64.EFI` → `last-good.efi.tmp` → fsync → сброс кеша → проверка подписи. До 3 попыток.
   5. gcroot `good.tmp` 
   6. last-good.efi.tmp rename → `last-good.efi` → fsync каталога.
   7. `good.tmp`→ rename → `good`.
   - Пока идёт копия, старый last-good защищён старым `good`; между rename и сменой ссылки новый — `default` (тот же toplevel). Окон без защиты нет.
6. **Общее для записи:** каждая неудачная попытка — warning в stderr (файл, попытка, причина), даже если следующая прошла: деградацию носителя должно быть видно. Запись не удалась за 3 попытки → удалить `.tmp`, выход; целевой файл не тронут.
7. **Ключи Secure Boot:** `/var/lib/sbctl` на зашифрованном корне. `uki-install` создаёт их, если нет (`sbctl create-keys`), enroll не делает.
8. **Enroll — в `install.sh`:**
   1. В самом начале, до disko: проверить Setup Mode. Нет — выход с подсказкой «Clear Secure Boot keys в BIOS».
   2. `nixos-install` (внутри — ключи, сборка, подпись).
   3. `sbctl verify` — всё на ESP подписано, иначе enroll не делаем.
   4. `sbctl enroll-keys --tpm-eventlog` — свои ключи + хеши option ROM этого железа (dGPU), без `--microsoft`.
   5. Сообщение: перезагрузиться, проверить `sbctl status`; если SB disabled — включить в BIOS.
   - Каждая установка генерирует новые ключи → переустановка всегда начинается с Clear keys.
9. **Запись в NVRAM** — одна статическая «NixOS» → `HD(PARTUUID ESP)/File(\EFI\BOOT\BOOTX64.EFI)`, создаёт `install.sh` идемпотентно (старые «NixOS» удалить). При `rebuild` не трогается; работает и после обновления SSD на другой машине. `uki-install` NVRAM не трогает никогда, `canTouchEfiVariables` не нужен.
   - Позиция в Boot Order — поле профиля: стенд — в конец (Arch остаётся дефолтом), финальный NVMe — первой.
10. **Пароль на BIOS обязателен:** без него физический доступ = выключить SB, защита теряет смысл.
11. **Установщик на Rust**, пишется заново (`scripts/src/uki-install/`). По соглашению из Readme: собирается руками, бинарь коммитится в `scripts/uki-install`, Nix только копирует (`runCommandLocal` + `install -Dm755`). Откат берёт версию своего коммита. **Статически под musl** (`x86_64-unknown-linux-musl`, цель в `.cargo/config.toml`, тулчейн — `nixos/rust.nix`): динамический бинарь зашивает путь к конкретному glibc в store, которого может не быть при `nixos-install` с ISO или после GC — установщик загрузчика от этого зависеть не должен. Зависимости — только `serde`, `serde_json` (bootspec) и `libc` (fadvise, fsync каталога, flock). Go-версия удаляется после приёмки в VM.

## Сценарии
- Несколько ребилдов без перезагрузки → меняется только BOOTX64, last-good остаётся рабочим.
- Новое не загрузилось → last-good.efi из UEFI, починить в git, rebuild.
- Первая загрузка после установки → last-good ещё нет (только BOOTX64 и live ISO), появится после первой удачной.

## Восстановление (уровни)
1. Сломано текущее → `last-good.efi` из UEFI «загрузка из файла».
2. Не помогло → установочная флешка NixOS (SB выключить на время ремонта): chroot или `nixos-install` поверх, ключи с диска; процедура в Readme. Либо переустановка.

## Отложено
- **`rescue.efi`** — проработан и отклонён в пользу флешки, замеры и решения в `tasks/rescue.md`.

## План
- [x] `uki-install` на Rust: установка и `mark-good`, разбор хвостов, flock, проверка места, inspect + verify, ретраи, gcroot'ы через `.tmp` + rename, отказ на specialisations
- [x] `loader.nix`: `boot.loader.external`, extension с путями и `efiSysMountPoint`, копирование готового `scripts/uki-install` в store, юнит `mark-good`
- [x] `install.sh`: проверка Setup Mode, `sbctl verify`, enroll, запись NVRAM с позицией из профиля, итоговое сообщение
- [x] профиль: поле позиции в Boot Order
- [ ] удалить Go-версию после приёмки в VM
- [x] Readme: порядок BIOS (SB on, Clear keys, пароль), повторный enroll после обновления BIOS/vBIOS, восстановление через last-good

## Приёмка (VM, OVMF secboot)
- [x] `nixos-rebuild build` проходит
- [x] `install.sh` без Setup Mode прерывается до disko
- [x] `nixos-install` кладёт `BOOTX64.EFI`, gcroot `default` есть
- [x] enroll → SB включён → система грузится; `sbctl verify` чистый
- [x] после первой загрузки есть `last-good.efi`, `good` = `default`
- [x] rebuild без перезагрузки: BOOTX64 новый, last-good старый
- [x] сломанное поколение (не доходит до multi-user) → last-good не меняется и грузится из Boot Manager OVMF
  - emergency (не смонтирована ФС): ок, last-good грузится через Boot From File при SB.
  - был баг: `multi-user.target` упал по `Requires=` → mark-good всё равно отметил поколение: `After=` не требует успеха. Исправлено `Requisite=multi-user.target`; проверено в VM — сломанное не отмечает, рабочее отмечает.
- [x] обрывы (kill между шагами 4.6–4.9 и 5.3–5.5) → следующий запуск приводит всё в порядок, gcroot'ы покрывают оба файла
- [x] нехватка места на ESP → выход до записи, ESP без изменений (точная проверка п.4.5 не достижима: реальный оверхед ~150 КБ < запаса оценки 1 МБ)
- [x] `nix-collect-garbage -d` не ломает BOOTX64 и last-good
- [x] запись «NixOS» в NVRAM ведёт на `BOOTX64.EFI`

## Приёмка на железе
- [ ] названия пунктов BIOS ASUS (SB, Clear keys) — в Readme
- [ ] «загрузка из файла» доступна из F8 или только из BIOS Setup (тогда — с паролем BIOS)
- [ ] стирает ли ASUS записи NVRAM на отключённый SSD

## Уточнения при реализации
- **Проверка подписи — `sbverify --cert /var/lib/sbctl/keys/db/db.pem`** (sbsigntool, путь `sbverify` в extension): `sbctl verify` проверяет только ESP целиком, отдельный файл не умеет. В `install.sh` `sbctl verify` остался, но он всегда завершается с 0 — разбирается текстовый вывод (`✗`, `BOOTX64.EFI is signed`).
- **`ukify inspect`:** сверяются размеры `.linux`/`.initrd` с файлами из bootspec и текст `.cmdline`/`.osrel`. Файл передаётся сразу после `inspect`, иначе ukify его не принимает.
- **fsync каталога gcroot'ов** после создания `*.tmp`: иначе при обрыве питания rename на ESP мог дойти до диска раньше симлинка, и новый toplevel остался бы без защиты от GC.
- **`mark-good` пропускает работу, если есть `default.tmp`:** установка не закончена, BOOTX64 мог уже смениться на непроверенный (обрыв без перезагрузки, ручной запуск юнита).
- **enroll:** `--tpm-eventlog`, если eventlog читается; без него — только VM (`--yes-this-might-brick-my-machine`), на железе `install.sh` выходит до disko.
- **Сборка бинаря:** `cargo build --release` в `scripts/src/uki-install` (цель musl из `.cargo/config.toml`), результат — `target/x86_64-unknown-linux-musl/release/uki-install`.
- Проверено в user+mount namespace (tmpfs вместо ESP, `/run`, `/var/lib`, gcroots): установка, mark-good, rebuild без перезагрузки, хвосты 4.8–4.9 и 5.6–5.7, нехватка места на быстрой оценке.

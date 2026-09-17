#!/usr/bin/env bash
set -euo pipefail

ROOT=$PWD

[ -f flake.nix ] || { echo "flake.nix не найден в $ROOT" >&2; exit 1; }

NIX=(nix --extra-experimental-features "nix-command flakes")

# Хосты — подкаталоги hosts/
mapfile -t HOSTS < <(find hosts -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)
[ ${#HOSTS[@]} -gt 0 ] || { echo "В hosts/ нет ни одного хоста" >&2; exit 1; }

echo "Какой хост установить?"
select HOST in "${HOSTS[@]}"; do
  [ -n "${HOST:-}" ] && break
done

# Имя пользователя берём из flake.nix (specialArgs.user)
USER_NAME=$("${NIX[@]}" eval --raw "$ROOT#nixosConfigurations.$HOST._module.specialArgs.user")

PROFILE="$ROOT#nixosConfigurations.$HOST._module.specialArgs.profile"

# 0. Secure Boot (tasks/uki.md). Свои ключи записываются только в Setup Mode —
# проверка до disko, чтобы не затереть диск и упереться в enroll в конце
EFIVARS=/sys/firmware/efi/efivars
[ -d "$EFIVARS" ] || { echo "Загрузка не в режиме UEFI" >&2; exit 1; }
SETUP_MODE=$(od -An -tu1 -j4 -N1 "$EFIVARS/SetupMode-8be4df61-93ca-11d2-aa0d-00e098032b8c" | tr -d ' ')
if [ "$SETUP_MODE" != 1 ]; then
  echo "Firmware не в Setup Mode: в BIOS Secure Boot → Clear Secure Boot keys, затем запустить заново" >&2
  exit 1
fi

# Без ключей Microsoft firmware отвергнет неподписанные option ROM (dGPU) —
# их хеши берутся из TPM eventlog этого железа. В VM option ROM не нужны
EVENTLOG=/sys/kernel/security/tpm0/binary_bios_measurements
if sudo test -r "$EVENTLOG"; then
  ENROLL_ARGS="--tpm-eventlog"
elif [ "$("${NIX[@]}" eval --raw "$PROFILE.environment")" = vm ]; then
  ENROLL_ARGS="--yes-this-might-brick-my-machine"
else
  echo "Нет TPM eventlog ($EVENTLOG): без хешей option ROM после enroll может не быть изображения" >&2
  exit 1
fi

echo
echo "Хост: $HOST"
echo "Пользователь: $USER_NAME"
echo "Диск(и) из hosts/$HOST/disko.nix:"
grep -E '^\s*device\s*=' "hosts/$HOST/disko.nix" || true
echo

# 1. Разметка + монтирование в /mnt
sudo nix --extra-experimental-features "nix-command flakes" \
    run github:nix-community/disko/latest -- \
    --mode destroy,format,mount --flake "$ROOT#$HOST"

# 2. Установка. Свой запрос пароля root у nixos-install отключён: с userborn в этот
# момент /etc/passwd ещё нет и passwd падает с «cannot determine your user name» — пароли в шаге 3
sudo nixos-install --no-root-passwd --flake "$ROOT#$HOST"

# 3. Пользователи и пароли.
# userborn создаёт /etc/{passwd,group,shadow} только своим systemd-юнитом при загрузке,
# activation-скрипта у него нет (NixOS/nixpkgs#408507), а в chroot nixos-enter systemd не работает.
# Поэтому выполняем то же, что юнит: команды и окружение берём из конфига хоста, а не дублируем.
# Файлы ложатся в верхний слой overlay /etc (/mnt/.rw-etc/upper); при первой загрузке userborn
# в mutable-режиме их дополняет, заданные здесь пароли сохраняются
USERBORN_SETUP=$("${NIX[@]}" eval --raw "$ROOT#nixosConfigurations.$HOST.config" --apply '
  c: let
    s = c.systemd.services.userborn;
    sc = s.serviceConfig;
    env = builtins.concatStringsSep " " (map (n: "${n}=${s.environment.${n}}") (builtins.attrNames s.environment));
    run = x: "env ${env} ${x}";
    # префикс «-» у ExecStart* в systemd — «ошибку игнорировать»
    pre = x: if builtins.substring 0 1 x == "-" then "${run (builtins.substring 1 (-1) x)} || true" else run x;
  in if !c.services.userborn.enable then "" else builtins.concatStringsSep "\n" (
    [ "mkdir -p /var/lib/${sc.StateDirectory}" ]
    ++ map pre (sc.ExecStartPre or [ ])
    ++ [ (run sc.ExecStart) ]
    ++ map run (sc.ExecStartPost or [ ])
  )')

# Одним вызовом: userborn, затем пароли root и пользователя
sudo nixos-enter --root /mnt -c "
  set -e
  $USERBORN_SETUP
  echo 'Пароль для root:'
  passwd root
  echo 'Пароль для пользователя $USER_NAME:'
  passwd $USER_NAME
"

# 4. Ключи и подписанный BOOTX64.EFI уже сделал uki-install внутри nixos-install.
# enroll — только если на ESP всё подписано: иначе с включённым SB не загрузится.
# sbctl verify всегда завершается с 0, поэтому разбирается вывод
VERIFY=$(sudo nixos-enter --root /mnt -c "ESP_PATH=/boot sbctl verify" 2>&1) || { echo "$VERIFY" >&2; exit 1; }
echo "$VERIFY"
if grep -q '✗' <<<"$VERIFY" || ! grep -q 'BOOTX64.EFI is signed' <<<"$VERIFY"; then
  echo "На ESP есть неподписанные файлы, enroll не делаю" >&2
  exit 1
fi

# 5. Свои ключи без --microsoft. Каждая установка генерирует новые ключи,
# поэтому переустановка всегда начинается с Clear Secure Boot keys
sudo nixos-enter --root /mnt -c "sbctl enroll-keys $ENROLL_ARGS"

# 6. Одна статическая запись «NixOS» → \EFI\BOOT\BOOTX64.EFI на ESP этого диска.
# Прежние «NixOS» удаляются; uki-install NVRAM не трогает никогда
EFIBOOTMGR=$("${NIX[@]}" build --no-link --print-out-paths "$ROOT#nixosConfigurations.$HOST.pkgs.efibootmgr^out")/bin/efibootmgr
nixos_entries() { sudo "$EFIBOOTMGR" | sed -n 's/^Boot\([0-9A-F]\{4\}\)[* ] NixOS\t.*/\1/p'; }
for n in $(nixos_entries); do
  sudo "$EFIBOOTMGR" -q -b "$n" -B
done
ESP_DEV=$(findmnt -no SOURCE /mnt/boot)
sudo "$EFIBOOTMGR" -q --create-only --disk "/dev/$(lsblk -no PKNAME "$ESP_DEV")" \
  --part "$(cat "/sys/class/block/$(basename "$ESP_DEV")/partition")" \
  --label NixOS --loader '\EFI\BOOT\BOOTX64.EFI'
ENTRY=$(nixos_entries)
ORDER=$(sudo "$EFIBOOTMGR" | sed -n 's/^BootOrder: //p')
case "$("${NIX[@]}" eval --raw "$PROFILE.bootOrder")" in
  first) ORDER="$ENTRY${ORDER:+,$ORDER}" ;;
  last)  ORDER="${ORDER:+$ORDER,}$ENTRY" ;;
esac
sudo "$EFIBOOTMGR" -q -o "$ORDER"

echo "Готово. Перезагрузиться; если Secure Boot выключен — включить в BIOS."
echo "После загрузки проверить: sbctl status (Secure Boot: Enabled, Setup Mode: Disabled)."

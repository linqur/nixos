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

echo "Готово."

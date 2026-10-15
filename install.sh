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

# 2. Установка
sudo nixos-install --flake "$ROOT#$HOST"

# 3. Пароль пользователя
echo "Пароль для пользователя $USER_NAME:"
sudo nixos-enter --root /mnt -c "passwd $USER_NAME"

echo "Готово."

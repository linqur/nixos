#!/usr/bin/env bash
# Первичная установка хоста из корня репозитория: ./install.sh
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

echo
echo "Хост: $HOST"
echo "Диск(и) из hosts/$HOST/disko.nix:"
grep -E '^\s*device\s*=' "hosts/$HOST/disko.nix" || true
echo

# 1. Разметка + монтирование в /mnt
sudo nix --extra-experimental-features "nix-command flakes" \
    run github:nix-community/disko/latest -- \
    --mode destroy,format,mount --flake "$ROOT#$HOST"

# 2. Установка
sudo nixos-install --flake "$ROOT#$HOST" --no-root-passwd

echo "Готово."

{ lib, ... }:

# Минимально жизнеспособный хост: загрузка, сеть, вход.
# Без nixos/imports.nix — только то, без чего система не стартует
{
  networking.hostName = "vm-minimal";

  imports = [
    ../../nixos/initrd.nix
    ../../nixos/loader.nix
    ../../nixos/net.nix
    ../../nixos/stateVersion.nix
    ../../nixos/user.nix # install.sh задаёт пароль и root, и пользователю
    ../../nixos/hardware.nix
  ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}

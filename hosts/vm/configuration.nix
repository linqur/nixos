{ lib, ...}:

{
  networking.hostName = "vm";

  imports = [
    ../../nixos/imports.nix
  ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}

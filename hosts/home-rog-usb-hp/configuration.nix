{ lib, ...}:

{
  networking.hostName = "home-rog-usb-hp";

  imports = [
    ../../nixos/imports.nix
  ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}

{ lib, modulesPath, ...}:

{
  networking.hostName = "vm";
  
  imports = [
    ../../nixos/imports.nix
    (modulesPath + "/profiles/qemu-guest.nix")
  ];
  
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  services.spice-vdagentd.enable = true;
}
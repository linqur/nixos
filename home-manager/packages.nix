{ pkgs, ... }:

{
  nixpkgs.config.allowUnfree = true;

  home.packages = with pkgs; [
    htop
    fastfetch
  ];
  
  programs.git.enable = true;
}
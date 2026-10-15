{ pkgs, ... }:

{
  home.packages = with pkgs; [
    htop
    fastfetch
  ];

  programs.git.enable = true;
}
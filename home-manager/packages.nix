{ pkgs, ... }:

{
  home.packages = with pkgs; [
    htop
    fastfetch
  ];

  programs.git.enable = true;
  programs.foot.enable = true;
  programs.alacrity.enable = true;
}
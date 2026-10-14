{ pkgs, ... }:

{
  nixpkgs.config.allowUnfree = true;

  home.packages = with pkgs; [
    pavucontrol
    htop
    fastfetch
    discord
  ];

  programs.vscode.enable = true;
  programs.foot.enable = true;
  programs.helix = true;
  programs.niri.enable = true;
}
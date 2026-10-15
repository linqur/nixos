{ pkgs, ... }:

{
  nixpkgs.config.allowUnfree = true;

  home.packages = with pkgs; [
    htop
    fastfetch
  ];

  programs.vscode.enable = true;
  programs.foot.enable = true;
  programs.helix.enable = true;
  programs.niri.enable = true;
  programs.git.enable = true;
}
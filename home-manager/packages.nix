{ pkgs, ... }:

{
  # lexical sorted
  home.packages = with pkgs; [
    htop
    fastfetch
  ];

  # lexical sorted
  programs.firefox.enable = true;
  programs.foot.enable = true;
  programs.fuzzel.enable = true;
  programs.git.enable = true;
  programs.keepassxc.enable = true;
  programs.vscode.enable = true;
}
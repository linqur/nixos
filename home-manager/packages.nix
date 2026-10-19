{ pkgs, inputs, ... }:

{
  # lexical sorted
  home.packages = (with pkgs; [
    htop
    fastfetch
    thunar
    tumbler  # превью изображений в Thunar
    xfconf  # хранилище настроек Thunar (D-Bus сервис)
  ]) ++ [
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code
  ];

  # lexical sorted
  programs.bash.enable = true;  # ~/.profile подключает home.sessionVariables
  programs.bat.enable = true;
  programs.eza.enable = true;
  programs.firefox.enable = true;
  programs.foot.enable = true;
  programs.fuzzel.enable = true;
  programs.git.enable = true;
  programs.imv.enable = true;
  programs.keepassxc.enable = true;
  programs.mpv.enable = true;
  programs.ssh.enable = true;
  programs.vscode.enable = true;
  programs.zathura.enable = true;
}
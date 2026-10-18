{ pkgs, inputs, ... }:

{
  # lexical sorted
  home.packages = (with pkgs; [
    htop
    fastfetch
  ]) ++ [
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code
  ];

  # lexical sorted
  programs.firefox.enable = true;
  programs.foot.enable = true;
  programs.fuzzel.enable = true;
  programs.git.enable = true;
  programs.keepassxc.enable = true;
  programs.ssh.enable = true;
  programs.vscode.enable = true;
}
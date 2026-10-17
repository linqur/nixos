{ pkgs, ... }:

{
  programs.vscode = {
    profiles.default = {
      extensions = with pkgs.vscode-extensions; [
        arcticicestudio.nord-visual-studio-code  # официальная тема Nord
        jnoortheen.nix-ide
      ];
      userSettings = {
        "workbench.colorTheme" = "Nord";
        "editor.fontFamily" = "'JetBrains Mono', monospace";
        "editor.fontSize" = 14;
        "terminal.integrated.fontFamily" = "'JetBrains Mono'";
      };
    };
  };
}

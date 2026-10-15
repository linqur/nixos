{ pkgs, ... }:

{
  programs.vscode = {
    profiles.default = {
      extensions = with pkgs.vscode-extensions; [
        jnoortheen.nix-ide
        # ...
      ];
      userSettings = {
        "editor.fontSize" = 14;
      };
    };
  };
}
{ lib, pkgs, ... }:

{
  programs.vscode = {
    profiles.default = {
      extensions = with pkgs.vscode-extensions; [
        jnoortheen.nix-ide
      ];
      userSettings = {
        "editor.fontSize" = lib.mkForce 14;  # перебить размер, который задаёт Stylix
      };
    };
  };
}
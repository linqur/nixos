{ pkgs, unstable, ... }:

{
  programs.vscode = {
    package = unstable.vscode;  # расширение code-spell-checker-russian требует VS Code >= 1.125
    profiles.default = {
      extensions = with pkgs.vscode-extensions; [
        arcticicestudio.nord-visual-studio-code  # официальная тема Nord
        jnoortheen.nix-ide
        golang.go
        rust-lang.rust-analyzer
        streetsidesoftware.code-spell-checker
      ] ++ pkgs.vscode-utils.extensionsFromVscodeMarketplace [
        {
          # русский словарь для spellchecker, в nixpkgs отсутствует
          publisher = "streetsidesoftware";
          name = "code-spell-checker-russian";
          version = "3.0.0";
          sha256 = "06yhxzsd2hrcv32fa28dp77qbckamndyscs8kpvllqjijww50jrs";
        }
      ];
      userSettings = {
        "workbench.colorTheme" = "Nord";
        "editor.fontFamily" = "'JetBrains Mono', monospace";
        "editor.fontSize" = 14;
        "terminal.integrated.fontFamily" = "'JetBrains Mono'";
        "cSpell.language" = "en,ru";
        "go.useLanguageServer" = true;
        "rust-analyzer.server.path" = "${pkgs.rust-analyzer}/bin/rust-analyzer";
      };
    };
  };

  # gopls для расширения Go (go и rustc/cargo ставятся отдельно)
  home.packages = [ pkgs.gopls ];
}

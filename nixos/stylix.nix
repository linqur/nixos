{ inputs, pkgs, ... }:

{
  imports = [ inputs.stylix.nixosModules.stylix ];

  stylix = {
    enable = true;
    autoEnable = false;  # красим только то, что включено явно
    polarity = "dark";
    base16Scheme = "${pkgs.base16-schemes}/share/themes/nord.yaml";

    fonts = {
      monospace = {
        package = pkgs.jetbrains-mono;
        name = "JetBrains Mono";
      };
      emoji = {
        package = pkgs.noto-fonts-color-emoji;
        name = "Noto Color Emoji";
      };
      sizes.terminal = 11;
    };

    targets = {
      console.enable = true;         # цвета TTY
      fontconfig.enable = true;      # системные шрифты по умолчанию
      font-packages.enable = true;   # установить шрифты из stylix.fonts
    };
  };
}

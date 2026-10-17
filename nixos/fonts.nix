{ pkgs, ... }:

{
  fonts = {
    packages = with pkgs; [
      jetbrains-mono
      noto-fonts           # Noto Sans/Serif с кириллицей
      noto-fonts-color-emoji
    ];

    # Шрифты по умолчанию для всех приложений (GTK, Qt, Firefox и т.д.)
    fontconfig.defaultFonts = {
      sansSerif = [ "Noto Sans" ];
      serif = [ "Noto Serif" ];
      monospace = [ "JetBrains Mono" ];
      emoji = [ "Noto Color Emoji" ];
    };
  };
}

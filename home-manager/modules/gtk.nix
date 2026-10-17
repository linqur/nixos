{ config, pkgs, ... }:

{
  gtk = {
    enable = true;
    colorScheme = "dark";  # заодно выставляет предпочтение тёмной схемы для libadwaita/портала

    # Nordic — GTK-тема на палитре Nord (фон nord0, акцент nord8)
    theme = {
      name = "Nordic";
      package = pkgs.nordic;
    };

    font = {
      name = "Noto Sans";
      size = 11;
    };

    # С stateVersion 26.05 GTK 4 не наследует тему GTK 3 сам, указываем явно
    gtk4.theme = config.gtk.theme;
  };
}

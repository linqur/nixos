{ config, pkgs, ... }:

{
  # Курсор для GTK, X11 (Xwayland) и переменных XCURSOR_*; белый вариант читается на тёмном фоне
  home.pointerCursor = {
    name = "Nordzy-cursors-white";
    package = pkgs.nordzy-cursor-theme;
    size = 24;
    gtk.enable = true;
    x11.enable = true;
  };

  gtk = {
    enable = true;
    colorScheme = "dark";  # заодно выставляет предпочтение тёмной схемы для libadwaita/портала

    # Nordic — GTK-тема на палитре Nord (фон nord0, акцент nord8)
    theme = {
      name = "Nordic";
      package = pkgs.nordic;
    };

    iconTheme = {
      name = "Nordzy-dark";
      package = pkgs.nordzy-icon-theme;
    };

    font = {
      name = "Noto Sans";
      size = 11;
    };

    # С stateVersion 26.05 GTK 4 не наследует тему GTK 3 сам, указываем явно
    gtk4.theme = config.gtk.theme;
  };
}

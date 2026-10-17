{ pkgs, ... }:

{
  qt = {
    enable = true;
    platformTheme.name = "qtct";  # иконки и шрифты Qt берутся из qt5ct/qt6ct
    style = {
      name = "kvantum";  # QT_STYLE_OVERRIDE=kvantum, ставит Kvantum для Qt5 и Qt6
    };

    qt5ctSettings.Appearance = {
      style = "kvantum";
      icon_theme = "Nordzy-dark";
    };
    qt6ctSettings.Appearance = {
      style = "kvantum";
      icon_theme = "Nordzy-dark";
    };
  };

  # Темы Kvantum (Nordic-Solid и др.) лежат в share/Kvantum пакета nordic
  home.packages = [ pkgs.nordic ];

  xdg.configFile."Kvantum/kvantum.kvconfig".text = ''
    [General]
    theme=Nordic-Solid
  '';
}

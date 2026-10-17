{ pkgs, ... }:

{
  qt = {
    enable = true;
    style = {
      name = "kvantum";  # QT_STYLE_OVERRIDE=kvantum, ставит Kvantum для Qt5 и Qt6
    };
  };

  # Темы Kvantum (Nordic-Solid и др.) лежат в share/Kvantum пакета nordic
  home.packages = [ pkgs.nordic ];

  xdg.configFile."Kvantum/kvantum.kvconfig".text = ''
    [General]
    theme=Nordic-Solid
  '';
}

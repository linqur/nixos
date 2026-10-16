{
  # Палитра и шрифты задаются в nixos/stylix.nix, здесь включены цели для приложений
  stylix.targets = {
    foot.enable = true;
    fuzzel.enable = true;
    gtk.enable = true;
    qt.enable = true;
    firefox = {
      enable = true;
      profileNames = [ "default" ];  # только шрифты; цвета интерфейса заданы в firefox.nix из палитры Stylix
    };
    vscode = {
      enable = true;
      profileNames = [ "default" ];
    };
  };
}

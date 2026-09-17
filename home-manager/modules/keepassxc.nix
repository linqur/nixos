{
  programs.keepassxc = {
    autostart = false;

    settings = {
      General = {
        ConfigVersion = 2;
      };

      GUI = {
        ApplicationTheme = "classic";  # системный Qt-стиль (Kvantum Nordic-Solid из qt.nix), а не встроенная тема KeePassXC
      };

      Security = {
        LockDatabaseIdle = true;
        LockDatabaseIdleSeconds = 300;
        ClearClipboardTimeout = 15;
      };
    };
  };
}

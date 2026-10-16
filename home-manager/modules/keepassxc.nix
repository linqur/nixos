{
  programs.keepassxc = {
    autostart = false;

    settings = {
      General = {
        ConfigVersion = 2;
      };

      GUI = {
        ApplicationTheme = "dark";
      };

      Security = {
        LockDatabaseIdle = true;
        LockDatabaseIdleSeconds = 300;
        ClearClipboardTimeout = 15;
      };
    };
  };
}

{ config, homeStateVersion, user, ... }:

{
  imports = [
    ./modules
    ./packages.nix
  ];

  home = {
    username = user;
    homeDirectory = "/home/${user}";
    stateVersion = homeStateVersion;

    # dotnet сам добавляет ".dotnet" к этому пути: ~/.local/share/dotnet/.dotnet вместо ~/.dotnet
    sessionVariables.DOTNET_CLI_HOME = "${config.xdg.dataHome}/dotnet";
    # ~/.config/claude вместо ~/.claude и ~/.claude.json
    sessionVariables.CLAUDE_CONFIG_DIR = "${config.xdg.configHome}/claude";
  };

  # Папки перед файлами в GTK-диалогах выбора файлов
  dconf.settings = {
    "org/gtk/settings/file-chooser".sort-directories-first = true;
    "org/gtk/gtk4/settings/file-chooser".sort-directories-first = true;
  };
}
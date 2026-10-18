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
  };
}
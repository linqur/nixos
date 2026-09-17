{ pkgs, ... }:

{
  programs.niri = {
    enable = true;
    useNautilus = false;
  };

  # X11-приложения (Steam): niri держит X-сокет и запускает xwayland-satellite при первом подключении
  environment.systemPackages = [ pkgs.xwayland-satellite ];
}

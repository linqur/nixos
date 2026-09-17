{
  security.rtkit.enable = true; # приоритет для реалтайм обработки звука

  services.pipewire = {
    enable = true;

    alsa.enable = true; # поддержка alsa
    alsa.support32Bit = true; # поддержка alsa 32 бита

    pulse.enable = true; # поддержка pulseaudio

    jack.enable = false; # отключаем сервер jack, т.к. отдельный сервер не нужен
  };

  # pipewire-pulse поднимается при входе, а не по первому подключению к сокету: при старте он делает
  # chmod 0700 на pulse/ и сбрасывает маску ACL, которую выставляет `game` (games.nix) для gamesjail
  systemd.user.services.pipewire-pulse.wantedBy = [ "default.target" ];
}
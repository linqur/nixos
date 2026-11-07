{
  security.rtkit.enable = true; # приоритет для реалтайм обработки звука

  services.pipewire = {
    enable = true;

    alsa.enable = true; # поддержка alsa
    alsa.support32Bit = true; # поддержка alsa 32 бита

    pulse.enable = true; # поддержка pulseaudio

    jack.enable = false; # отключаем сервер jack, т.к. отдельный сервер не нужен
  };
}
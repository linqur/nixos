{
  # Конфиг уже проверяется при сборке (services.logrotate.checkConfig), повтор на каждой загрузке не нужен
  systemd.services.logrotate-checkconf.enable = false;
}

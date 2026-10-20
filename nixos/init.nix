{
  # Инициализация без bash/perl: /etc и пользователи готовятся при сборке, а не на каждой загрузке.
  # Экспериментально — см. «Что помнить при правке конфига» в Readme.md.
  system.etc.overlay.enable = true; # /etc — образ erofs из сборки, монтируется overlay
  services.userborn.enable = true; # пользователи из готового описания вместо update-users-groups.pl
  system.nixos-init.enable = true; # stage 2 без activationScripts: они молча игнорируются
}

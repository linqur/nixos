{ config, lib, ... }:

let
  # userborn не пишет subuid/subgid — собираем их сами из users.users.*.sub{Uid,Gid}Ranges
  subIdFile = ranges: start: lib.concatStrings (lib.concatMap
    (u: map (r: "${u.name}:${toString r.${start}}:${toString r.count}\n") u.${ranges})
    (lib.filter (u: u.enable) (lib.attrValues config.users.users)));
in
{
  # Инициализация без bash/perl: /etc и пользователи готовятся при сборке, а не на каждой загрузке.
  # Экспериментально — см. «Что помнить при правке конфига» в Readme.md.
  system.etc.overlay.enable = true; # /etc — образ erofs из сборки, монтируется overlay
  services.userborn.enable = true; # пользователи из готового описания вместо update-users-groups.pl
  system.nixos-init.enable = true; # stage 2 без activationScripts: они молча игнорируются

  environment.etc.subuid = { text = subIdFile "subUidRanges" "startUid"; mode = "0644"; };
  environment.etc.subgid = { text = subIdFile "subGidRanges" "startGid"; mode = "0644"; };
}

{ lib, pkgs, profile, enums, ... }:

# Порог заряда: на 100% и в тепле литиевая батарея изнашивается быстрее всего
# ASUS сбрасывает порог при перезагрузке, поэтому он выставляется на каждой загрузке
let
  threshold = "75";
in
lib.mkIf (profile.environment == enums.environment.laptop) {
  # два правила: батарея и драйвер asus-wmi появляются в разном порядке, порог доступен после обоих
  # $$ — буквальный $ для udev
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="power_supply", KERNEL=="BAT*", TEST=="charge_control_end_threshold", ATTR{charge_control_end_threshold}="${threshold}"
    ACTION=="bind", SUBSYSTEM=="platform", DRIVER=="asus-nb-wmi", RUN+="${pkgs.runtimeShell} -c 'for f in /sys/class/power_supply/BAT*/charge_control_end_threshold; do echo ${threshold} > $$f; done'"
  '';
}

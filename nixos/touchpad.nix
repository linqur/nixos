{ lib, pkgs, profile, user, ... }:

# Вкл/выкл тачпада отвязкой драйвера i2c-hid от устройства, а не через libinput/niri:
# при unbind ядро освобождает IRQ и усыпляет тачпад, касания не доходят даже до прерываний.
# После bind ядро заново создаёт input-устройства, niri подхватывает их как hotplug.
# Отвязка живёт до перезагрузки: на загрузке тачпад снова включён.
let
  dev = "/sys/bus/i2c/devices/${profile.touchpad}";

  # от root: писать в bind/unbind может только он
  toggle = pkgs.writeShellScript "touchpad-toggle-root" ''
    if [ -e ${dev}/driver ]; then
      echo ${profile.touchpad} > ${dev}/driver/unbind
    else
      # drivers_probe сам подбирает драйвер (i2c_hid_acpi), имя не нужно
      echo ${profile.touchpad} > /sys/bus/i2c/drivers_probe
    fi
  '';
in
lib.mkIf (profile ? touchpad) {
  # ${user} может только переключать тачпад: путь в store неизменяем, аргументов нет
  security.sudo.extraRules = [{
    users = [ user ];
    commands = [{ command = "${toggle}"; options = [ "NOPASSWD" ]; }];
  }];

  environment.systemPackages = [
    (pkgs.writeShellScriptBin "touchpad-toggle" "exec /run/wrappers/bin/sudo -n ${toggle}")
  ];
}

{ ... }:

# Bluetooth не используется: адаптер отключён полностью, а не просто без bluez
{
  # демон bluez и его пакеты не ставятся
  hardware.bluetooth.enable = false;
  # без модулей hci0 не появляется, адаптер не потребляет энергию и не виден в rfkill
  boot.blacklistedKernelModules = [ "btusb" "bluetooth" ];
}

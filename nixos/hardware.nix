{ lib, modulesPath, profile, enums, ... }:

# Железо, не привязанное к отдельной функции: микрокод, прошивки, гостевые драйверы VM
let
  vm = profile.environment == enums.environment.vm;
in
{
  # модули virtio и гостевые драйверы QEMU
  imports = lib.optional vm (modulesPath + "/profiles/qemu-guest.nix");

  # исправления процессора, в том числе безопасности; применяется в initrd до загрузки ядра
  hardware.cpu.intel.updateMicrocode = profile.cpu == enums.cpu.intel;

  # linux-firmware: без неё нет Wi-Fi (iwlwifi), прошивки нужны i915, Bluetooth, звуку
  hardware.enableRedistributableFirmware = !vm;

  # буфер обмена и подгонка разрешения под окно virt-manager
  services.spice-vdagentd.enable = vm;
  # включить гостевой модуль внутри vm
  services.qemuGuest.enable = vm;
}

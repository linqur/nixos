{ enums, ...}:

{
  gpu = enums.gpu.nvidia_intel;
  environment = enums.environment.laptop;
  storage = enums.storage.nvme;
  cpu = enums.cpu.intel;
  # NixOS на внутреннем диске заменяет Arch — загрузка по умолчанию
  bootOrder = enums.bootOrder.first;
  # lspci: 00:02.0 Intel UHD, 01:00.0 RTX 5060
  gpuBusId = { intel = "PCI:0:2:0"; nvidia = "PCI:1:0:0"; };
  # монитор по «производитель модель серийник» из `niri msg outputs`: имя разъёма плавает между загрузками
  # (eDP-1 или eDP-2 — nvidia-drm и i915 нумеруют разъёмы в порядке инициализации)
  # scale 1.25 даёт ровно 2048x1280 логических px (при 1.3 было дробное 1969.2x1230.8)
  display = { name = "BOE NE180QDM-NZC Unknown"; mode = "2560x1600"; scale = 1.25; };
  # i2c-устройство тачпада для touchpad.nix: `ls /sys/bus/i2c/devices`, у него в input/ есть «Touchpad»
  touchpad = "i2c-ASUF1209:00";
}

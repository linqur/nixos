{ enums, ...}:

{
  gpu = enums.gpu.nvidia_intel;
  environment = enums.environment.laptop;
  storage = enums.storage.usb;
  cpu = enums.cpu.intel;
  # Arch на внутреннем диске остаётся загрузкой по умолчанию
  bootOrder = enums.bootOrder.last;
  # lspci: 00:02.0 Intel UHD, 01:00.0 RTX 5060
  gpuBusId = { intel = "PCI:0:2:0"; nvidia = "PCI:1:0:0"; };
  # имя разъёма как в Arch; заменить на «производитель модель серийник» из `niri msg outputs`
  display = { name = "eDP-2"; mode = "2560x1600"; scale = 1.25; };  # ровно 2048x1280 логических px (при 1.3 было дробное 1969.2x1230.8)
}

{
  gpu = {
    intel = "intel";
    nvidia_intel = "nvidia_intel";
    virtual = "virtual";
  };

  environment = {
    laptop = "laptop";
    vm = "vm";
  };

  cpu = {
    intel = "intel";
    virtual = "virtual";
  };

  storage = {
    nvme = "nvme";
    usb = "usb";
    virtio = "virtio";
  };

  # позиция записи «NixOS» в Boot Order (её создаёт install.sh)
  bootOrder = {
    first = "first";
    last = "last";
  };
}

{ lib, profile, enums, ... }:

{
  boot.consoleLogLevel = 4; # подробность вывода лога в консоль при запуске
  boot.initrd.availableKernelModules = [ # доступные модули для initrd
    "usbhid"        # HID поверх USB
    "hid_generic"   # HID без вендор-квирков
    "xhci_hcd"      # ядро драйвера USB3
    "xhci_pci"      # xhci на PCI; AMD 800-серии — отдельный xhci_pci_prom21
    "i8042"         # PS/2-контроллер; в ноутбуке его эмулирует EC
    "atkbd"         # клавиатура на i8042
  ] ++ lib.optionals (profile.storage == enums.storage.nvme) [
    "nvme"          # свой блочный драйвер, мимо SCSI/sd_mod
    "vmd"           # Intel VMD (RST): на ROG NVMe за ним, PCI-домен 10000:
  ] ++ lib.optionals (profile.storage == enums.storage.usb) [
    "uas"           # USB Attached SCSI: мост внешнего SSD
    "usb_storage"   # bulk-only мосты; uas зависит от него
    "sd_mod"        # SCSI-диск /dev/sdX
  ] ++ lib.optionals (profile.storage == enums.storage.virtio) [
    "virtio_pci"    # virtio-шина на PCI
    "virtio_blk"    # /dev/vda
  ];
  boot.initrd.luks.cryptoModules = [ # модули расшифровки
    "dm_crypt"      # расшифровщик; luksroot добавляет его и dm_mod сам, здесь для ясности
    "dm_mod"        # device-mapper
    "aes"           # шифр
    "xts"           # режим
    "ecb"           # workaround: modprobe не выдаёт ecb зависимостью xts
    "aesni_intel"   # аппаратный AES; реализация выбирается один раз, в initrd
  ];
  boot.initrd.includeDefaultModules = false; # дефолтный набор nixpkgs: SATA/PATA, legacy USB, HID-квирки
  boot.initrd.allowMissingModules = false; # false — сборка падает, если модуля нет в ядре; builtin засчитывается
  boot.initrd.systemd.enable = true;
  # boot.initrd.kernelModules = []; загруженные модули initrd
}
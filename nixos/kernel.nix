{ pkgs, unstable, ... }: {
  boot.kernelPackages = unstable.linuxPackages_latest;
  boot.consoleLogLevel = 4; # подробность вывода лога в консоль при запуске
  boot.initrd.availableKernelModules = [ # доступные модули для initrd
    "nvme"          # диск ноутбука; свой блочный драйвер, мимо SCSI/sd_mod

    # ВРЕМЕННО, только под VM: корень на /dev/vda. Снять при переезде на железо.
    "virtio_pci"    # virtio-шина на PCI
    "virtio_blk"    # /dev/vda

    "usbhid"        # HID поверх USB
    "hid_generic"   # HID без вендор-квирков
    "xhci_hcd"      # ядро драйвера USB3
    "xhci_pci"      # xhci на PCI; AMD 800-серии — отдельный xhci_pci_prom21
    "i8042"         # PS/2-контроллер; в ноутбуке его эмулирует EC
    "atkbd"         # клавиатура на i8042
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
  # boot.kernel.features = ;  включение/выключение фич, runtime конфигурация
  # boot.extraModulePackages = ; модули для конкретного ядра не пересборка ядра
  # boot.kernelModules = ; модули которые грузятся явным образом
  # boot.blacklistedKernelModules = ; модули которые запрещено грузить автоматичекски
  # boot.extraModprobeConfig = ; конфигурация параметров модулей более глубоко чем kernelParams, но после initrd
  # boot.kernel.sysctl = ; конфигурация ядра в runtime
  # boot.kernelParams = ; параметры запуска
  # boot.kernelPatches = ; патчи и конфигурация compile-time всегда пересборка
}
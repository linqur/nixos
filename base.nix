# Единый конфиг без flakes: всё, что было в flake.nix и nixos/*.nix (разметка — в disko.nix).
# Это база для последующей декомпозиции и возврата на flakes.
#
# Использование (из установщика):
#   разметка:  ./disko-run.sh   (disko.nix, уничтожает /dev/vda!)
#   установка: nixos-install -I nixos-config=$PWD/base.nix
{ config, pkgs, lib, ... }:
let
  # Замена flake-инпутам. Без flake.lock версии не зафиксированы: fetchTarball
  # без sha256 тянет текущее содержимое ветки (кэш tarball-ов ~1 час).
  # Пин (sha256 или конкретный коммит) — задача после стабилизации базы.
  # Stable (nixos-26.05) приходит как <nixpkgs> из канала установщика.
  disko = builtins.fetchTarball "https://github.com/nix-community/disko/archive/latest.tar.gz";

  # «Stable база + unstable точечно»: бывший specialArgs.unstable.
  unstable = import (builtins.fetchTarball
    "https://github.com/NixOS/nixpkgs/archive/nixos-unstable.tar.gz") {
    system = "x86_64-linux";
    config.allowUnfree = true;
  };

  # Свой установщик UKI на ESP (см. scripts/cmd/uki-install). Собирается
  # из исходников, а не берётся готовым бинарём: так он воспроизводим
  # из git + Nix и входит в closure поколения вместе со своей версией.
  uki-install = pkgs.buildGoModule {
    pname = "uki-install";
    version = "0";
    # Без flake в store копируется вся директория как есть, поэтому
    # cleanSource отсекает мусор (.git, result и т.п.). Локальный scripts/bin/,
    # если появится, лучше держать в .gitignore и не полагаться на это.
    src = lib.cleanSource ./scripts;
    # Только stdlib, зависимостей нет — хеш вендоринга не нужен.
    vendorHash = null;
    subPackages = [ "cmd/uki-install" ];
  };
in
{
  imports = [
    "${disko}/module.nix"
    # Разметка живёт отдельно: disko CLI принимает только файл с одним
    # disko.devices, а модуль выше по ней строит fileSystems и luks в initrd.
    ./disko.nix
  ];

  # ---------------------------------------------------------------- система

  networking.hostName = "home-rog";
  # Было в let flake.nix, но нигде не использовалось. Без неё сборка ругается.
  system.stateVersion = "26.05";

  # ----------------------------------------------------------------- ядро

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

  # ------------------------------------------------------------ загрузчик

  boot.loader.external.enable = true;
  boot.loader.external.installHook = "${uki-install}/bin/uki-install";

  # Всё, что uki-install получает от Nix, — одним блоком. Попадает в
  # $toplevel/boot.json рядом с секцией org.nixos.bootspec.v1, установщик
  # читает только его и не лезет ни в PATH, ни во внутренности toplevel.
  # Пути интерполируются, поэтому пакеты входят в closure поколения: они
  # есть на диске после nixos-install, а откат берёт версии своего
  # поколения. Цикла нет: ни один из путей не зависит от toplevel.
  boot.bootspec.extensions."io.github.linqur.uki" = {
    # Отдельная сборка systemd с ukify. В systemPackages её нет
    # сознательно: иначе её systemctl и прочее могли бы перекрыть
    # системные в sw/bin.
    ukify = "${pkgs.systemdUkify}/bin/ukify";
    # Stub из той же сборки, что и ukify: версии гарантированно совпадают,
    # даже если systemd.package когда-нибудь переопределят.
    stub = "${pkgs.systemdUkify}/lib/systemd/boot/efi/linuxx64.efi.stub";
    sbctl = "${pkgs.sbctl}/bin/sbctl";
    # Тот же файл, что станет /etc/os-release поколения. Из него stub
    # берёт имя и версию для секции .osrel.
    osRelease = "${config.environment.etc."os-release".source}";
  };

  # ----------------------------------------------------------- user
  users.users.linqur = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    password = "123";
  };
}

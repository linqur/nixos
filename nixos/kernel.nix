{ pkgs, ... }: 

{
  boot.kernelPackages = pkgs.linuxPackages_latest;
  # конфигурация ядра в runtime
  boot.kernel.sysctl = {
    # не тормозить процесс на split lock (по ~10 мс на ловушку): клиент Steam их ловит, в играх под Proton — фризы
    "kernel.split_lock_mitigate" = 0;
  };
  # boot.kernelParams = ; параметры запуска
  # boot.kernelPatches = ; патчи и конфигурация compile-time всегда пересборка
  # boot.kernel.features = ;  включение/выключение фич, runtime конфигурация
  # boot.extraModulePackages = ; модули для конкретного ядра не пересборка ядра
  # boot.kernelModules = ; модули которые грузятся явным образом
  # boot.blacklistedKernelModules = ; модули которые запрещено грузить автоматичекски
  # boot.extraModprobeConfig = ; конфигурация параметров модулей более глубоко чем kernelParams, но после initrd
}
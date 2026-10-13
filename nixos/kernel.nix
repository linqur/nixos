{ pkgs, ... }: 

{
  boot.kernelPackages = pkgs.linuxPackages_latest;
  # boot.kernel.sysctl = ; конфигурация ядра в runtime
  # boot.kernelParams = ; параметры запуска
  # boot.kernelPatches = ; патчи и конфигурация compile-time всегда пересборка
  # boot.kernel.features = ;  включение/выключение фич, runtime конфигурация
  # boot.extraModulePackages = ; модули для конкретного ядра не пересборка ядра
  # boot.kernelModules = ; модули которые грузятся явным образом
  # boot.blacklistedKernelModules = ; модули которые запрещено грузить автоматичекски
  # boot.extraModprobeConfig = ; конфигурация параметров модулей более глубоко чем kernelParams, но после initrd
}
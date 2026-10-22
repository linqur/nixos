{ config, lib, pkgs, inputs, profile, enums, ... }:

# NVIDIA без тонкой настройки: экран рисует Intel, NVIDIA — по запросу через `nvidia-offload <программа>`
# Ядро из stable, драйвер из unstable; как закрепить и вернуться — Readme «NVIDIA»
let
  # null — ядро из kernel.nix (_latest); "7_2" — ветка 7.2; "lts" — LTS
  kernelPin = null;

  # драйвер из nixpkgs-nvidia, собранный под текущее ядро
  drivers = config.boot.kernelPackages.callPackage
    "${inputs.nixpkgs-nvidia}/pkgs/os-specific/linux/nvidia-x11" { };
in
lib.mkIf (profile.gpu == enums.gpu.nvidia_intel) {
  boot.kernelPackages = lib.mkIf (kernelPin != null) (lib.mkForce
    (if kernelPin == "lts" then pkgs.linuxPackages else pkgs."linuxPackages_${kernelPin}"));

  warnings =
    lib.optional (kernelPin != null) "ядро закреплено: ${kernelPin}"
    ++ lib.optional (inputs.nixpkgs-nvidia.rev != inputs.nixpkgs-unstable.rev)
      "драйвер NVIDIA ${drivers.latest.version} не из текущего unstable";

  # включает модуль nvidia и запрещает nouveau; X-сервер при этом не запускается
  services.xserver.videoDrivers = [ "modesetting" "nvidia" ];

  hardware.nvidia = {
    open = true; # Blackwell (RTX 50xx) работает только с открытыми модулями
    # latest: Blackwell лучше поддержан в свежих драйверах; не beta
    package = drivers.latest;
    modesetting.enable = true; # DRM KMS, без него нет Wayland (в Arch — nvidia.modeset=1)

    # dGPU засыпает без нагрузки (RTD3); без этого карта постоянно включена и греет ноутбук
    powerManagement.finegrained = true;

    prime = {
      offload.enable = true;
      offload.enableOffloadCmd = true; # команда nvidia-offload
      intelBusId = profile.gpuBusId.intel;
      nvidiaBusId = profile.gpuBusId.nvidia;
    };
  };
}

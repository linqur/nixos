{ config, lib, profile, enums, ... }:

# NVIDIA без тонкой настройки: экран рисует Intel, NVIDIA — по запросу через `nvidia-offload <программа>`
lib.mkIf (profile.gpu == enums.gpu.nvidia_intel) {
  # включает модуль nvidia и запрещает nouveau; X-сервер при этом не запускается
  services.xserver.videoDrivers = [ "modesetting" "nvidia" ];

  hardware.nvidia = {
    open = true; # Blackwell (RTX 50xx) работает только с открытыми модулями
    # latest: новое ядро (_latest) и Blackwell лучше поддержаны в свежих драйверах; не beta
    package = config.boot.kernelPackages.nvidiaPackages.latest;
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

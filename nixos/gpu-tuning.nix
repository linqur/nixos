{ lib, pkgs, profile, enums, ... }:

# Undervolt dGPU: сдвиг кривой V/F и потолок частоты, подобраны в tasks/gpu.md.
# Переживают засыпание dGPU (D3cold), сбрасываются перезагрузкой и перезагрузкой драйвера
let
  offset = 350; # МГц; стабилен на 900–2700, +450 — сбой (Xid 109/119/154)
  maxClock = 2700; # МГц; против стока −6% FPS за −31% ватт. Не хватает FPS — 2900, offset не трогать

  # status, set, reset, log в CSV; scripts/gpu-uv.py
  gpu-uv = pkgs.writers.writePython3Bin "gpu-uv" {
    libraries = [ pkgs.python3Packages.nvidia-ml-py ];
    flakeIgnore = [ "E501" ];
  } (builtins.readFile ../scripts/gpu-uv.py);

  # после сна системы применить заново: что настройки его переживают, не проверено
  sleepTargets = [ "suspend.target" "hibernate.target" "hybrid-sleep.target" "suspend-then-hibernate.target" ];
in
lib.mkIf (profile.gpu == enums.gpu.nvidia_intel) {
  environment.systemPackages = [ gpu-uv ];

  systemd.services.gpu-uv = {
    description = "dGPU undervolt: offset +${toString offset} МГц, потолок ${toString maxClock} МГц";
    wantedBy = [ "multi-user.target" ] ++ sleepTargets;
    after = [ "systemd-modules-load.service" ] ++ sleepTargets;
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${lib.getExe gpu-uv} set --offset ${toString offset} --max ${toString maxClock}";
    };
  };
}

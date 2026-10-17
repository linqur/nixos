{ pkgs, lib, ... }:

let
  version = "0.9.5";

  src = pkgs.fetchFromGitHub {
    owner = "dborovcanin";
    repo = "dbar";
    rev = "v${version}";
    hash = "sha256-m8hr82G1zycwfgPtPmCRHFR2CkMRj/0II5Q6EwmA13s=";
  };

  dbar = pkgs.rustPlatform.buildRustPackage {
    pname = "dbar";
    inherit version src;

    cargoLock.lockFile = "${src}/Cargo.lock";

    # clang + libclang нужны bindgen для привязок PipeWire
    nativeBuildInputs = [ pkgs.pkg-config pkgs.rustPlatform.bindgenHook ];
    buildInputs = with pkgs; [ libxkbcommon wayland pipewire ];

    meta = {
      description = "Lightweight Wayland status bar";
      homepage = "https://github.com/dborovcanin/dbar";
      license = lib.licenses.asl20;
      mainProgram = "dbar";
    };
  };

  # Готовая Nord-тема из репозитория dbar, подогнанная под наш шрифт и раскладки
  config = builtins.replaceStrings
    [
      ''font = "Adwaita Sans 17"''
      ''"Serbian (Latin)" = "SR"''
    ]
    [
      ''font = "JetBrains Mono 13"''
      ''"Russian" = "RU"''
    ]
    (builtins.readFile "${src}/examples/nord.toml");
in
{
  home.packages = [ dbar ];

  xdg.configFile."dbar/config.toml".text = config;
}

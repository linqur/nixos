{ unstable, lib, ... }:

let
  version = "0.9.5";
  base = "https://github.com/dborovcanin/dbar/releases/download/v${version}";

  # Релизный бинарник собран под glibc 2.43, а в stable её ещё нет (2.42),
  # поэтому патчим его под glibc и pipewire из unstable
  dbar = unstable.stdenv.mkDerivation {
    pname = "dbar";
    inherit version;

    src = unstable.fetchurl {
      url = "${base}/dbar-linux-x86_64";
      hash = "sha256-sIc0IEWuLjPXUNBsOozVsN9noRPgiQetBjBHKx41LGw=";
    };

    dontUnpack = true;

    nativeBuildInputs = [ unstable.autoPatchelfHook ];
    buildInputs = [
      unstable.pipewire
      unstable.stdenv.cc.cc.lib  # libgcc_s
    ];

    installPhase = ''
      install -Dm755 $src $out/bin/dbar
    '';

    meta = {
      description = "Lightweight Wayland status bar";
      homepage = "https://github.com/dborovcanin/dbar";
      license = lib.licenses.asl20;
      mainProgram = "dbar";
    };
  };

  # Готовая Nord-тема из репозитория dbar, подогнанная под наш шрифт и раскладки
  nordExample = unstable.fetchurl {
    url = "https://raw.githubusercontent.com/dborovcanin/dbar/v${version}/examples/nord.toml";
    hash = "sha256-77SSTFzz7UWAKcILT0bIJoadswWP5DMTe+yZJgEhIw8=";
  };

  config = builtins.replaceStrings
    [
      ''font = "Adwaita Sans 17"''
      ''"Serbian (Latin)" = "SR"''
    ]
    [
      ''font = "JetBrains Mono 13"''
      ''"Russian" = "RU"''
    ]
    (builtins.readFile nordExample);
in
{
  home.packages = [ dbar ];

  xdg.configFile."dbar/config.toml".text = config;
}

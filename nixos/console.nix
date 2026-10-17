{ pkgs, ... }:

let
  n = import ../lib/nord.nix;
  hex = c: builtins.substring 1 6 c;  # палитра TTY без «#»
in
{
  console = {
    earlySetup = true;  # применить шрифт и цвета сразу при старте initrd
    packages = [ pkgs.terminus_font ];
    font = "ter-v24n";  # растровый шрифт с кириллицей; JetBrains Mono в TTY недоступен (ядро не умеет TTF)

    # Порядок ANSI 0-15: обычные, затем яркие
    colors = map hex [
      n.nord1 n.nord11 n.nord14 n.nord13 n.nord9 n.nord15 n.nord8 n.nord5
      n.nord3 n.nord11 n.nord14 n.nord13 n.nord9 n.nord15 n.nord7 n.nord6
    ];
  };
}

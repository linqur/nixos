let
  n = import ../../lib/nord.nix;
  hex = c: builtins.substring 1 6 c;  # foot принимает цвета без «#»
in
{
  programs.foot = {
    settings = {
      main = {
        font = "JetBrains Mono:size=11";
        pad = "6x6";
      };

      scrollback.lines = 10000;

      cursor = {
        style = "beam";
        blink = "yes";
      };

      mouse.hide-when-typing = "yes";

      # Палитра Nord для терминала: https://www.nordtheme.com/docs/ports/terminal-app/colors
      colors-dark = {
        background = hex n.nord0;
        foreground = hex n.nord4;
        selection-background = hex n.nord2;
        selection-foreground = hex n.nord4;
        cursor = "${hex n.nord0} ${hex n.nord4}";  # цвет текста под курсором и цвет самого курсора

        regular0 = hex n.nord1;
        regular1 = hex n.nord11;
        regular2 = hex n.nord14;
        regular3 = hex n.nord13;
        regular4 = hex n.nord9;
        regular5 = hex n.nord15;
        regular6 = hex n.nord8;
        regular7 = hex n.nord5;

        bright0 = hex n.nord3;
        bright1 = hex n.nord11;
        bright2 = hex n.nord14;
        bright3 = hex n.nord13;
        bright4 = hex n.nord9;
        bright5 = hex n.nord15;
        bright6 = hex n.nord7;
        bright7 = hex n.nord6;
      };
    };
  };
}

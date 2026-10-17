let
  n = import ../../lib/nord.nix;
  rgba = c: "${builtins.substring 1 6 c}ff";  # fuzzel принимает RRGGBBAA без «#»
in
{
  programs.fuzzel = {
    settings = {
      main = {
        terminal = "foot";
        layer = "overlay";
        font = "JetBrains Mono:size=11";
      };
      colors = {
        background = rgba n.nord0;
        text = rgba n.nord4;
        message = rgba n.nord4;
        prompt = rgba n.nord8;
        placeholder = rgba n.nord3;
        input = rgba n.nord6;
        match = rgba n.nord8;
        selection = rgba n.nord2;
        selection-text = rgba n.nord6;
        selection-match = rgba n.nord8;
        counter = rgba n.nord3;
        border = rgba n.nord3;
      };
      border = {
        width = 1;
        radius = 6;
      };
    };
  };
}

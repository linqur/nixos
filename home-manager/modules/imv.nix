let
  n = import ../../lib/nord.nix;
  hex = c: builtins.substring 1 6 c;  # imv принимает цвета без «#»
in
{
  programs.imv = {
    settings = {
      options = {
        background = hex n.nord0;
        overlay_text_color = hex n.nord4;
        overlay_background_color = hex n.nord1;
        overlay_font = "JetBrains Mono:11";
      };
    };
  };
}

let
  n = import ../../lib/nord.nix;
in
{
  programs.mpv = {
    config = {
      background-color = n.nord0;
      osd-font = "JetBrains Mono";
      osd-font-size = 28;
      osd-color = n.nord4;
      osd-border-color = n.nord0;
      osd-back-color = n.nord1;
      sub-font = "Noto Sans";
      sub-color = n.nord6;
      sub-border-color = n.nord0;
      hwdec = "auto-safe";
      keep-open = "yes";  # после конца файла встаёт на паузу на последнем кадре, а не закрывается
    };
  };
}

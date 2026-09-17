let
  n = import ../../lib/nord.nix;
in
{
  programs.zathura = {
    options = {
      font = "JetBrains Mono 11";
      selection-clipboard = "clipboard";

      default-bg = n.nord0;
      default-fg = n.nord4;
      statusbar-bg = n.nord1;
      statusbar-fg = n.nord4;
      inputbar-bg = n.nord1;
      inputbar-fg = n.nord4;
      notification-bg = n.nord1;
      notification-fg = n.nord4;
      notification-error-bg = n.nord11;
      notification-error-fg = n.nord6;
      notification-warning-bg = n.nord13;
      notification-warning-fg = n.nord0;
      highlight-color = n.nord13;
      highlight-active-color = n.nord8;
      completion-bg = n.nord1;
      completion-fg = n.nord4;
      completion-highlight-bg = n.nord2;
      completion-highlight-fg = n.nord6;
      completion-group-bg = n.nord1;
      completion-group-fg = n.nord8;
      index-bg = n.nord0;
      index-fg = n.nord4;
      index-active-bg = n.nord2;
      index-active-fg = n.nord6;

      # Тёмный режим для страниц документа в палитре Nord
      recolor = true;
      recolor-lightcolor = n.nord0;
      recolor-darkcolor = n.nord4;
      recolor-keephue = true;
    };
  };
}

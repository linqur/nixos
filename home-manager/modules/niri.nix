let
  n = import ../../lib/nord.nix;  # официальная палитра Nord
in
{
  # Цвета Nord + геометрия как в Hyprland (gaps_in 5 / gaps_out 10 / border 2 / rounding 6)
  xdg.configFile."niri/config.kdl".text = ''
    input {
        keyboard {
            xkb {
                layout "us,ru"
                options "grp:win_space_toggle"
            }
            numlock
        }
        touchpad {
            tap
        }
        focus-follows-mouse
    }

    output "Virtual-1" {
        mode custom=true "2560x1600@240"
        scale 1.3
    }

    layout {
        gaps 10
        struts {
            left 5
            right 5
            top 5
            bottom 5
        }

        background-color "${n.nord0}"

        default-column-width { proportion 0.5; }

        focus-ring {
            off
        }

        border {
            width 2
            active-color "${n.nord3}"
            inactive-color "${n.nord1}"
            urgent-color "${n.nord11}"
        }

        shadow {
            off
        }
    }

    prefer-no-csd

    window-rule {
        geometry-corner-radius 6
        clip-to-geometry true
    }

    hotkey-overlay {
        skip-at-startup
    }

    binds {
        Mod+Q { spawn "foot"; }
        Mod+R { spawn "fuzzel"; }
        Mod+W { spawn "firefox"; }
        Mod+Escape { close-window; }
        Mod+Shift+Escape { quit; }
        Mod+V { toggle-window-floating; }
        Mod+F { maximize-column; }
        Mod+Shift+F { fullscreen-window; }

        // Фокус и перемещение (как в Hyprland: hjkl)
        Mod+H { focus-column-left; }
        Mod+L { focus-column-right; }
        Mod+J { focus-window-or-workspace-down; }
        Mod+K { focus-window-or-workspace-up; }
        Mod+Shift+H { move-column-left; }
        Mod+Shift+L { move-column-right; }
        Mod+Shift+J { move-window-down-or-to-workspace-down; }
        Mod+Shift+K { move-window-up-or-to-workspace-up; }

        // Размер
        Mod+Minus { set-column-width "-10%"; }
        Mod+Equal { set-column-width "+10%"; }

        // Рабочие столы
        Mod+1 { focus-workspace 1; }
        Mod+2 { focus-workspace 2; }
        Mod+3 { focus-workspace 3; }
        Mod+4 { focus-workspace 4; }
        Mod+5 { focus-workspace 5; }
        Mod+6 { focus-workspace 6; }
        Mod+7 { focus-workspace 7; }
        Mod+8 { focus-workspace 8; }
        Mod+9 { focus-workspace 9; }
        Mod+Shift+1 { move-column-to-workspace 1; }
        Mod+Shift+2 { move-column-to-workspace 2; }
        Mod+Shift+3 { move-column-to-workspace 3; }
        Mod+Shift+4 { move-column-to-workspace 4; }
        Mod+Shift+5 { move-column-to-workspace 5; }
        Mod+Shift+6 { move-column-to-workspace 6; }
        Mod+Shift+7 { move-column-to-workspace 7; }
        Mod+Shift+8 { move-column-to-workspace 8; }
        Mod+Shift+9 { move-column-to-workspace 9; }

        Mod+WheelScrollDown cooldown-ms=150 { focus-workspace-down; }
        Mod+WheelScrollUp cooldown-ms=150 { focus-workspace-up; }

        Print { screenshot; }
    }
  '';
}

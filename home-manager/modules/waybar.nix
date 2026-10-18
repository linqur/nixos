let
  n = import ../../lib/nord.nix;

  # Глифы Nerd Font (Font Awesome) задаём кодами, чтобы не хранить в файле невидимые символы
  icon = code: builtins.fromJSON ''"\u${code}"'';
in
{
  programs.waybar = {
    enable = true;

    settings = [
      {
        layer = "top";

        # Слева метрики системы, справа статусы; у каждого элемента своя плашка
        modules-left = [ "battery" "temperature" ];
        modules-center = [ "niri/workspaces" ];
        modules-right = [ "tray" "niri/language" "clock" ];

        battery = {
          states = {
            warning = 30;
            critical = 15;
          };
          format = "{icon} {capacity}%";
          format-charging = "${icon "f0e7"} {capacity}%";
          format-plugged = "${icon "f1e6"} {capacity}%";
          format-icons = map icon [ "f244" "f243" "f242" "f241" "f240" ];
          tooltip = false;
        };

        # Датчик Package id 0 у coretemp; hwmon-path-abs не зависит от номера hwmonN, он меняется между загрузками
        temperature = {
          hwmon-path-abs = "/sys/devices/platform/coretemp.0/hwmon";
          input-filename = "temp1_input";
          critical-threshold = 90;
          format = "${icon "f2c9"} {temperatureC}°C";
          tooltip = false;
        };

        "niri/workspaces" = {
          format = "{value}";
          disable-click = true;
        };

        tray = {
          spacing = 10;
          icon-size = 16;
        };

        # format-<lang> подставляется в «{}», именованные плейсхолдеры (например {short}) тут не работают
        "niri/language" = {
          format = "{}";
          format-en = "EN";
          format-ru = "RU";
        };

        clock = {
          format = "{:%H:%M}";
          tooltip = false;
        };
      }
    ];

    style = ''
      * {
        font-family: "JetBrains Mono";
        font-size: 14px;
        min-height: 0;
        border: none;
        border-radius: 0;
        transition: none;
      }

      window#waybar {
        background: transparent;
        color: ${n.nord8};
      }

      /* Отступы по краям: 15px, как у окон niri (struts 5 + gaps 10); 6px из них даёт margin плашки */
      .modules-left {
        margin-left: 9px;
      }

      .modules-right {
        margin-right: 15px;
      }

      /* Плашки: у каждого элемента своя, «висят» над фоном niri */
      #battery,
      #temperature,
      #tray,
      #language,
      #clock {
        margin: 5px 0 0 6px;
        padding: 4px 12px;
        border-radius: 8px;
        background: ${n.nord1};
      }

      #workspaces {
        margin-top: 5px;
        padding: 4px 6px;
        border-radius: 8px;
        background: ${n.nord1};
      }

      #workspaces button {
        padding: 0 6px;
        min-width: 0;
        background: transparent;
        color: ${n.nord4};
        opacity: 0.5;
      }

      #workspaces button.focused {
        color: ${n.nord8};
        opacity: 1;
      }

      #workspaces button.urgent {
        color: ${n.nord11};
        opacity: 1;
      }

      #battery.warning:not(.charging) {
        color: ${n.nord13};
      }

      #battery.critical:not(.charging),
      #temperature.critical {
        color: ${n.nord11};
      }

      #tray > .passive {
        -gtk-icon-effect: dim;
      }

      #tray > .needs-attention {
        -gtk-icon-effect: highlight;
      }
    '';
  };
}

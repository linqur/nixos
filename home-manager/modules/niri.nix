{ lib, pkgs, profile, ... }:

let
  n = import ../../lib/nord.nix;  # официальная палитра Nord

  # свой минимальный Wayland-клиент на zwlr_gamma_control_unstable_v1 (см.
  # scripts/src/wgamma): wlsunset падал на равных -t/-T, а после фикса —
  # получал failed от niri (fd читается с текущей позиции, не с начала).
  # Бинарь собран и закоммичен в scripts/wgamma — здесь только копируем его
  # в store, без пересборки при каждом rebuild.
  wgamma = pkgs.runCommandLocal "wgamma" { } ''
    install -Dm755 ${../../scripts/wgamma} $out/bin/wgamma
  '';

  # OSD громкости и яркости (scripts/src/wosd), тоже готовый бинарь. Демона
  # нет: процесс живёт, пока идут нажатия, и выходит через ~1.2 с после
  # последнего. Шрифты и wpctl/busctl подставляет обёртка.
  wosd = pkgs.runCommandLocal "wosd" { nativeBuildInputs = [ pkgs.makeBinaryWrapper ]; } ''
    install -Dm755 ${../../scripts/wosd} $out/libexec/wosd
    makeWrapper $out/libexec/wosd $out/bin/wosd \
      --set WOSD_TEXT_FONT ${pkgs.jetbrains-mono}/share/fonts/truetype/JetBrainsMono-Regular.ttf \
      --set WOSD_ICON_FONT ${pkgs.nerd-fonts.symbols-only}/share/fonts/truetype/NerdFonts/Symbols/SymbolsNerdFont-Regular.ttf \
      --prefix PATH : ${lib.makeBinPath [ pkgs.wireplumber pkgs.systemd ]}
  '';

  # вкл/выкл тачпада на уровне ядра (nixos/touchpad.nix); Fn+F10 на ASUS шлёт XF86TouchpadToggle
  touchpadBinds = lib.optionalString (profile ? touchpad) (lib.concatStringsSep "\n    " [
    ''XF86TouchpadToggle allow-when-locked=true { spawn "touchpad-toggle"; }''
    ''Mod+T { spawn "touchpad-toggle"; }''
  ]);

  # без profile.display — режим и масштаб по умолчанию (VM: режим задаётся снаружи, virtio-gpu)
  # mode без частоты: niri берёт максимальную для разрешения
  output = lib.optionalString (profile ? display) ''
    output "${profile.display.name}" {
        mode "${profile.display.mode}"
        scale ${toString profile.display.scale}
    }
  '';
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

    ${output}

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

        preset-column-widths {
            proportion 0.25
            proportion 0.5
            proportion 0.75
            proportion 1.0
        }

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

    spawn-at-startup "waybar"
    // фильтр синего статично на 4000K, без учёта времени/геопозиции — свой wgamma, см. выше
    spawn-at-startup "${wgamma}/bin/wgamma"

    // Сам niri делает плавающими диалоги и окна фиксированного размера; здесь это отключено.
    // Плавающим окно станет только по правилу ниже с open-floating true: последующие правила перекрывают это.
    window-rule {
        geometry-corner-radius 6
        clip-to-geometry true
        open-floating false
    }

    // Firefox открывается на всю ширину колонки (не fullscreen, отступы и рамка остаются)
    window-rule {
        match app-id=r#"^firefox$"#
        exclude app-id=r#"^firefox$"# title="^(Picture-in-Picture|Картинка в картинке)$"
        open-maximized true
    }

    window-rule {
        match app-id=r#"^steam$"#
        open-maximized true
    }

    // Darktide в настройках игры остаётся «в окне» 1920x1080: окно больше экрана или
    // полноэкранный режим из игры зависают до первого кадра. На весь экран разворачивает niri
    window-rule {
        match title=r#"^Warhammer 40,000: Darktide$"#
        open-fullscreen true
    }


    // PiP плавает в правом нижнем углу: 1/4 ширины экрана (2048 логических px) в пропорции 16:10.
    // Это только стартовые значения: размер и положение потом можно менять.
    window-rule {
        match app-id=r#"^firefox$"# title="^(Picture-in-Picture|Картинка в картинке)$"
        open-floating true
        default-column-width { fixed 512; }
        default-window-height { fixed 320; }
        default-floating-position x=15 y=15 relative-to="bottom-right"
    }

    hotkey-overlay {
        skip-at-startup
    }

    binds {
        Mod+Q { spawn "foot"; }
        Mod+R { spawn "fuzzel"; }
        Mod+W { spawn "firefox"; }
        Mod+M { spawn "thunar"; }
        Mod+Escape { close-window; }
        Mod+F4 { spawn "sh" "-c" "kill -9 $(niri msg -j focused-window | grep -Eo '.pid.:[0-9]+' | grep -Eo '[0-9]+$')"; }
        Mod+Shift+Escape { quit; }
        Mod+V { toggle-window-floating; }
        Mod+F { maximize-column; }
        Mod+Shift+F { fullscreen-window; }

        // Фокус и перемещение (стрелки)
        Mod+Left { focus-column-left; }
        Mod+Right { focus-column-right; }
        Mod+Down { focus-window-or-workspace-down; }
        Mod+Up { focus-window-or-workspace-up; }
        Mod+Shift+Left { move-column-left; }
        Mod+Shift+Right { move-column-right; }
        Mod+Shift+Down { move-window-down-or-to-workspace-down; }
        Mod+Shift+Up { move-window-up-or-to-workspace-up; }

        // Размер
        Mod+Minus { switch-preset-column-width-back; }
        Mod+Equal { switch-preset-column-width; }

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

        Mod+Print { screenshot; }

        // Громкость и яркость с OSD, шаг 1%. Зажатая клавиша повторяет бинд
        // с частотой автоповтора клавиатуры (дефолт niri: 600 мс, 25/с).
        XF86AudioRaiseVolume allow-when-locked=true { spawn "${wosd}/bin/wosd" "volume" "up"; }
        XF86AudioLowerVolume allow-when-locked=true { spawn "${wosd}/bin/wosd" "volume" "down"; }
        XF86AudioMute allow-when-locked=true { spawn "${wosd}/bin/wosd" "volume" "mute"; }
        XF86MonBrightnessUp allow-when-locked=true { spawn "${wosd}/bin/wosd" "brightness" "up"; }
        XF86MonBrightnessDown allow-when-locked=true { spawn "${wosd}/bin/wosd" "brightness" "down"; }

        ${touchpadBinds}
    }
  '';
}

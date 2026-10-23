{ pkgs, ... }:

{
  console = {
    earlySetup = true;  # применить шрифт и цвета сразу при старте initrd
    packages = [ pkgs.terminus_font ];
    font = "ter-v24n";  # растровый шрифт с кириллицей; JetBrains Mono в TTY недоступен (ядро не умеет TTF)

    # Kanagawa Dragon (терминальные цвета kanagawa.nvim): тёмная, тёплая, приглушённая —
    # TTY видно только до niri, где фильтра синего ещё нет. Отступления от оригинала:
    # чёрный фон, текст на ступень тусклее. Уходит в vt.default_* в cmdline —
    # действует с первой строки ядра.
    # Порядок ANSI 0-15: обычные, затем яркие
    colors = [
      "000000"  # 0  фон — чистый чёрный (в оригинале dragonBlack0 #0d0c0c)
      "c4746e"  # 1  dragonRed
      "8a9a7b"  # 2  dragonGreen2
      "c4b28a"  # 3  dragonYellow
      "8ba4b0"  # 4  dragonBlue2
      "a292a3"  # 5  dragonPink
      "8ea4a2"  # 6  dragonAqua
      "a6a69c"  # 7  основной текст — dragonGray (в оригинале oldWhite #c8c093)
      "737c73"  # 8  приглушённый — dragonAsh (в оригинале dragonGray, он стал текстом)
      "e46876"  # 9  waveRed — [FAILED], ошибки должны читаться
      "87a987"  # 10 springGreen — [  OK  ] у systemd (жирный = яркий вариант)
      "e6c384"  # 11 carpYellow — предупреждения
      "7fb4ca"  # 12 springBlue
      "938aa9"  # 13 springViolet1
      "7aa89f"  # 14 waveAqua2
      "c8c093"  # 15 жирный текст, имена юнитов в «Starting …» — oldWhite (в оригинале dragonWhite #c5c9c5)
    ];
  };
}

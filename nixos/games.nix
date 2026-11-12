{ pkgs, user, ... }:

# Игры под отдельным пользователем gamesjail: Steam, а дальше лаунчеры и эмуляторы через ту же обёртку.
# Ничего не работает в фоне: `game <программа>` поднимает доступы и свою шину, всё завершается вместе с программой.
# Программа получает X (через Xwayland), звук через сокет pulse и пустую сессионную шину gamesjail;
# Wayland не даём: niri раздаёт обычным клиентам снимки экрана, буфер обмена и виртуальный ввод.
# Видеокарту выбирает программа: клиент Steam на Intel, dGPU — `game nvidia-offload <программа>`
# или `nvidia-offload %command%` в параметрах игры (sudo сбрасывает окружение, поэтому после game, не до)
let
  jailUser = "gamesjail";
  home = "/var/lib/${jailUser}";
  # sudo не создаёт сессию logind, поэтому /run/user/<uid> у gamesjail нет
  runDir = "/run/${jailUser}";
  # отдельный сокет pipewire-pulse: на pulse/ в /run/user/<uid> ACL не держится, любой клиент libpulse
  # от linqur (Firefox, speech-dispatcher, pactl) делает там chmod 0700 и обнуляет маску
  pulseDir = "/run/${jailUser}-pulse";
  # библиотеки игр, моды, non-Steam игры; linqur правит файлы, но ничего отсюда не запускает
  gamesDir = "/srv/games";
  gamesLink = "/home/${user}/games";
  gamesAcl = "u:${jailUser}:rwx,u:${user}:rwx,g:gameshare:rwx,m::rwx,d:u:${jailUser}:rwx,d:u:${user}:rwx,d:g:gameshare:rwx,d:m::rwx";

  # MangoHud внутри FHS-окружения Steam: `mangohud %command%` в параметрах запуска
  steam = pkgs.steam.override { extraPkgs = p: [ p.mangohud ]; };

  # своя сессионная шина на каждый запуск, к шине linqur доступа нет — поэтому нет трея и ссылок в браузере linqur.
  # Сокет — файл в каталоге gamesjail: абстрактный сокет из стандартного session.conf виден всем пользователям.
  # Службы не активируются: launcher-service Steam запускает сам
  busConfig = pkgs.writeText "gamesjail-session.conf" ''
    <!DOCTYPE busconfig PUBLIC "-//freedesktop//DTD D-Bus Bus Configuration 1.0//EN"
     "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
    <busconfig>
      <type>session</type>
      <listen>unix:dir=${runDir}</listen>
      <auth>EXTERNAL</auth>
      <policy context="default">
        <allow send_destination="*"/>
        <allow receive_sender="*"/>
        <allow own="*"/>
      </policy>
    </busconfig>
  '';

  # запускается от gamesjail через sudo, аргументы — программа. DISPLAY и LANG/LC_* sudo сохраняет сам
  jailExec = pkgs.writeShellScript "gamesjail-exec" ''
    export XDG_RUNTIME_DIR=${runDir}
    # pipewire-pulse linqur; нативный сокет pipewire не открыт, SDL и Proton переходят на pulse
    export PULSE_SERVER=unix:${pulseDir}/native
    # профиль gamesjail первым: в системном PATH `steam` — это обёртка linqur
    export PATH=/etc/profiles/per-user/${jailUser}/bin:/run/current-system/sw/bin
    export SHELL=${pkgs.bash}/bin/bash
    # вывод только через X; Qt, SDL и GTK умеют Wayland и без подсказки ищут его
    unset WAYLAND_DISPLAY
    export QT_QPA_PLATFORM=xcb SDL_VIDEODRIVER=x11 GDK_BACKEND=x11
    cd
    # шина завершается вместе с программой
    exec ${pkgs.dbus}/bin/dbus-run-session --config-file=${busConfig} \
      --dbus-daemon=${pkgs.dbus}/bin/dbus-daemon -- "$@"
  '';

  # команда для основного пользователя: открывает gamesjail доступ к X и звуку и запускает программу.
  # Вывод пока только X; режим wayland (сокет через wp_security_context_v1) — в планах, см. tasks/steam.md
  game = pkgs.writeShellScriptBin "game" ''
    set -euo pipefail
    if [ $# -eq 0 ]; then
      echo "использование: game <программа> [аргументы]" >&2
      exit 2
    fi
    if [ -z "''${DISPLAY-}" ]; then
      echo "game: нет DISPLAY, Xwayland не запущен" >&2
      exit 1
    fi

    ${pkgs.xhost}/bin/xhost +SI:localuser:${jailUser} >/dev/null
    # pipewire-pulse запускается по основному сокету, а сокет для gamesjail появляется только вместе с ним
    ${pkgs.systemd}/bin/systemctl --user start pipewire-pulse.service

    exec /run/wrappers/bin/sudo -u ${jailUser} -H -- ${jailExec} "$@"
  '';

  # ярлыки и иконки из пакета Steam, Exec=steam попадает в эту команду
  steamLauncher = pkgs.runCommand "gamesjail-steam" { } ''
    mkdir -p $out/bin
    ln -s ${pkgs.writeShellScript "steam" ''exec ${game}/bin/game steam "$@"''} $out/bin/steam
    ln -s ${steam}/share $out/share
  '';
in
{
  users.groups.${jailUser} = { };
  users.groups.gameshare.members = [ user jailUser ];
  # виртуальный геймпад Remote Play и Steam Input; сессия linqur такие устройства не принимает (virtual-input.nix)
  users.groups.uinput.members = [ jailUser ];

  users.users.${jailUser} = {
    isSystemUser = true;
    group = jailUser;
    inherit home;
    packages = [ steam ];
  };

  # linqur может запускать от gamesjail что угодно: это не повышение прав, gamesjail слабее
  security.sudo.extraRules = [{
    users = [ user ];
    runAs = jailUser;
    commands = [{ command = "${jailExec}"; options = [ "NOPASSWD" ]; }];
  }];

  environment.systemPackages = [ game steamLauncher ];

  # unix:native — обычный сокет; список заменяет значение по умолчанию, поэтому он тоже здесь
  services.pipewire.extraConfig.pipewire-pulse."90-gamesjail" = {
    "pulse.properties"."server.address" = [ "unix:native" "unix:${pulseDir}/native" ];
  };

  # клиент Steam и большая часть игр 32-битные
  hardware.graphics.enable32Bit = true;

  # Steam Link / Remote Play; слушает только запущенный Steam
  networking.firewall = {
    allowedUDPPortRanges = [{ from = 27031; to = 27036; }];
    allowedTCPPorts = [ 27036 27037 ];
  };

  systemd.tmpfiles.rules = [
    "d ${home} 0700 ${jailUser} ${jailUser} -"
    "d ${runDir} 0700 ${jailUser} ${jailUser} -"
    "d ${pulseDir} 0750 ${user} gameshare -"
    "d ${gamesDir} 2770 ${user} gameshare -"
    "L ${gamesLink} - - - - ${gamesDir}"
    # то же в доме gamesjail: диалоги выбора файлов открываются там
    "L ${home}/games - - - - ${gamesDir}"
    "a+ ${gamesDir} - - - - ${gamesAcl}"
  ];
}

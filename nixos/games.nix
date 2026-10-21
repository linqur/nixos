{ pkgs, user, ... }:

# Игры под отдельным пользователем gamesjail: Steam, а дальше лаунчеры и эмуляторы через ту же обёртку.
# Ничего не работает в фоне: `game <программа>` поднимает доступы и прокси, всё завершается вместе с программой.
# Программа получает X (через Xwayland), звук через сокет pulse и отфильтрованную шину linqur;
# Wayland не даём: niri раздаёт обычным клиентам снимки экрана, буфер обмена и виртуальный ввод.
let
  jailUser = "gamesjail";
  home = "/var/lib/${jailUser}";
  # sudo не создаёт сессию logind, поэтому /run/user/<uid> у gamesjail нет
  runDir = "/run/${jailUser}";
  # библиотеки игр, моды, non-Steam игры; linqur правит файлы, но ничего отсюда не запускает
  gamesDir = "/srv/games";
  gamesLink = "/home/${user}/games";
  gamesAcl = "u:${jailUser}:rwx,u:${user}:rwx,g:gameshare:rwx,m::rwx,d:u:${jailUser}:rwx,d:u:${user}:rwx,d:g:gameshare:rwx,d:m::rwx";

  # MangoHud внутри FHS-окружения Steam: `mangohud %command%` в параметрах запуска
  steam = pkgs.steam.override { extraPkgs = p: [ p.mangohud ]; };

  # ссылки открываются в браузере linqur через портал; xdg-open внутри Steam берёт $BROWSER.
  # Если вызов не прошёл, Steam открывает страницу в своём окне CEF
  openUri = pkgs.writeShellScript "gamesjail-open-uri" ''
    # без явного типа gdbus передаёт {} строкой, и портал отвечает InvalidArgs
    exec ${pkgs.glib}/bin/gdbus call --session \
      --dest org.freedesktop.portal.Desktop --object-path /org/freedesktop/portal/desktop \
      --method org.freedesktop.portal.OpenURI.OpenURI "" "$1" "@a{sv} {}" >/dev/null
  '';

  # запускается от gamesjail через sudo; первый аргумент — сокет прокси D-Bus, дальше программа.
  # DISPLAY и LANG/LC_* sudo сохраняет сам
  jailExec = pkgs.writeShellScript "gamesjail-exec" ''
    bus=$1
    shift
    export XDG_RUNTIME_DIR=${runDir}
    export DBUS_SESSION_BUS_ADDRESS=unix:path=$bus
    # pipewire-pulse linqur; нативный сокет pipewire не открыт, SDL и Proton переходят на pulse
    export PULSE_SERVER=unix:/run/user/$(${pkgs.coreutils}/bin/id -u ${user})/pulse/native
    # профиль gamesjail первым: в системном PATH `steam` — это обёртка linqur
    export PATH=/etc/profiles/per-user/${jailUser}/bin:/run/current-system/sw/bin
    export SHELL=${pkgs.bash}/bin/bash
    export BROWSER=${openUri}
    # вывод только через X; Qt, SDL и GTK умеют Wayland и без подсказки ищут его
    unset WAYLAND_DISPLAY
    export QT_QPA_PLATFORM=xcb SDL_VIDEODRIVER=x11 GDK_BACKEND=x11
    cd
    exec "$@"
  '';

  # команда для основного пользователя: открывает gamesjail доступ к X, звуку и шине и запускает программу.
  # Каталог /run/user/<uid> пересоздаётся при каждом входе, поэтому права выдаются на каждый запуск.
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
    # pipewire-pulse запускается по сокету и при старте делает chmod 0700 на pulse/, обнуляя маску ACL;
    # поднимаем его до выдачи прав, иначе первое подключение из gamesjail закроет доступ всем следующим
    ${pkgs.systemd}/bin/systemctl --user start pipewire-pulse.service
    ${pkgs.acl}/bin/setfacl -m u:${jailUser}:x "$XDG_RUNTIME_DIR" "$XDG_RUNTIME_DIR/pulse"
    ${pkgs.acl}/bin/setfacl -m u:${jailUser}:rw "$XDG_RUNTIME_DIR/pulse/native"

    # свой прокси на каждый запуск: несколько программ могут работать одновременно
    dir=$(${pkgs.coreutils}/bin/mktemp -d "$XDG_RUNTIME_DIR/${jailUser}.XXXXXX")
    trap '${pkgs.coreutils}/bin/rm -rf "$dir"' EXIT
    ${pkgs.coreutils}/bin/mkfifo "$dir/ready"
    # белый список: трей waybar (вызовы от waybar к значку входящие, их прокси не фильтрует) и открытие ссылок.
    # systemd --user, секреты и агенты закрыты: через systemd --user был бы выход в сессию linqur
    ${pkgs.xdg-dbus-proxy}/bin/xdg-dbus-proxy --fd=3 "$DBUS_SESSION_BUS_ADDRESS" "$dir/bus" --filter \
      --talk=org.kde.StatusNotifierWatcher \
      --own='org.kde.*' \
      --call=org.freedesktop.portal.Desktop=org.freedesktop.portal.OpenURI.OpenURI@/org/freedesktop/portal/desktop \
      --broadcast='org.freedesktop.portal.Desktop=org.freedesktop.portal.Request.*@/org/freedesktop/portal/desktop/request/*' \
      3>"$dir/ready" &
    # прокси пишет байт, когда готов, и завершается, когда этот конец закрыт — то есть вместе с обёрткой
    exec 4<"$dir/ready"
    if ! read -r -n1 -u4 _; then
      echo "game: прокси D-Bus не запустился" >&2
      exit 1
    fi
    ${pkgs.acl}/bin/setfacl -m u:${jailUser}:x "$dir"
    ${pkgs.acl}/bin/setfacl -m u:${jailUser}:rw "$dir/bus"

    # без exec: обёртка держит прокси и убирает каталог после выхода программы
    /run/wrappers/bin/sudo -u ${jailUser} -H -- ${jailExec} "$dir/bus" "$@"
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
    "d ${gamesDir} 2770 ${user} gameshare -"
    "L ${gamesLink} - - - - ${gamesDir}"
    "a+ ${gamesDir} - - - - ${gamesAcl}"
  ];
}

{ pkgs, user, ... }:

# Rootless Docker под отдельным пользователем dockdev.
# Демон стартует лениво: systemd держит сокет, dockerd поднимается при первом обращении.
let
  dockUser = "dockdev";
  dockUid = 1001;
  sock = "/run/user/${toString dockUid}/docker.sock";
  # сокет самого dockerd, наружу смотрит только прокси-сокет выше
  realSock = "/run/user/${toString dockUid}/docker-real.sock";
  # проекты вне дома: dockdev в /home/${user} не пускаем совсем, в доме только симлинк
  projects = "/srv/projects";
  projectsLink = "/home/${user}/projects";

  # запускается от dockdev через sudo
  mkDockdevExec = name: bin: pkgs.writeShellScript "dockdev-${name}" ''
    export DOCKER_HOST=unix://${sock}
    # lazydocker/dive сами зовут docker (compose, build): обёртка из PATH не годится, sudo в dockdev её не пустит
    export PATH=${pkgs.docker}/bin:$PATH
    exec ${bin} "$@"
  '';

  dockdevDocker = mkDockdevExec "docker" "${pkgs.docker}/bin/docker";

  # клиенты, которые ходят в сокет напрямую; сам сокет доступен только dockdev
  dockdevTools = {
    docker = dockdevDocker;
    lazydocker = mkDockdevExec "lazydocker" "${pkgs.lazydocker}/bin/lazydocker";
    dive = mkDockdevExec "dive" "${pkgs.dive}/bin/dive";
  };

  daemonJson = pkgs.writeText "daemon.json" (builtins.toJSON {
    # бинарный формат со сжатием; json-file без ротации растёт бесконечно. Действует на новые контейнеры
    log-driver = "local";
    log-opts = { max-size = "10m"; max-file = "3"; };
    # иначе контейнеры наследуют LimitNOFILE=infinity, на нём часть софта медленно стартует и ест память
    default-ulimits.nofile = { Name = "nofile"; Soft = 1024; Hard = 524288; };
    # кэш BuildKit чистит сам демон, пока работает; корневой раздел всего 34G
    builder.gc = { enabled = true; defaultKeepStorage = "8GB"; };
    max-concurrent-downloads = 6;
  });

  # команды для основного пользователя, работают и в скриптах/IDE.
  # Клиент работает от dockdev, а тот путь через симлинк в доме не пройдёт: переходим в реальный
  # каталог и переписываем пути аргументов (-v, -f, контекст сборки) на ${projects}
  mkWrapper = name: exec: pkgs.writeShellScriptBin name ''
    cd -P . 2>/dev/null || true
    args=()
    for a in "$@"; do args+=("''${a//"${projectsLink}"/"${projects}"}"); done
    exec /run/wrappers/bin/sudo -u ${dockUser} -H -- ${exec} "''${args[@]}"
  '';
in
{
  users.groups.${dockUser} = { };
  users.groups.devshare.members = [ user dockUser ];

  users.users.${dockUser} = {
    isNormalUser = true;
    uid = dockUid;
    group = dockUser;
    # rootlesskit без них не стартует; userborn их не пишет — /etc/subuid собирается в init.nix. Не пересекаемся с linqur (100000)
    subUidRanges = [{ startUid = 200000; count = 65536; }];
    subGidRanges = [{ startGid = 200000; count = 65536; }];
    # user manager поднимается на загрузке, сам dockerd — только по запросу
    linger = true;
  };

  security.sudo.extraRules = [{
    users = [ user ];
    runAs = dockUser;
    commands = map (exec: { command = "${exec}"; options = [ "NOPASSWD" ]; }) (builtins.attrValues dockdevTools);
  }];

  environment.systemPackages = builtins.attrValues (builtins.mapAttrs mkWrapper dockdevTools);

  systemd.user.sockets.docker = {
    description = "Docker socket (rootless, lazy)";
    wantedBy = [ "sockets.target" ];
    unitConfig.ConditionUser = dockUser;
    socketConfig = {
      ListenStream = sock;
      SocketMode = "0600";
      Service = "docker-proxy.service";
    };
  };

  # dockerd под rootlesskit не принимает сокет от systemd напрямую, поэтому проксируем
  systemd.user.services.docker-proxy = {
    description = "Docker socket proxy (rootless)";
    requires = [ "docker.service" ];
    after = [ "docker.service" ];
    unitConfig.ConditionUser = dockUser;
    serviceConfig.ExecStart = "${pkgs.systemd}/lib/systemd/systemd-socket-proxyd ${realSock}";
  };

  # повторяет virtualisation.docker.rootless, но без автостарта и только для dockdev
  systemd.user.services.docker = {
    description = "Docker Application Container Engine (Rootless)";
    # нужен newuidmap
    path = [ "/run/wrappers" ];
    unitConfig = {
      ConditionUser = dockUser;
      StartLimitInterval = "60s";
      StartLimitBurst = 3;
    };
    serviceConfig = {
      Type = "notify";
      ExecStart = "${pkgs.docker}/bin/dockerd-rootless --config-file=${daemonJson} --host=unix://${realSock}";
      ExecReload = "${pkgs.procps}/bin/kill -s HUP $MAINPID";
      TimeoutSec = 0;
      RestartSec = 2;
      Restart = "always";
      LimitNOFILE = "infinity";
      LimitNPROC = "infinity";
      LimitCORE = "infinity";
      Delegate = true;
      NotifyAccess = "all";
      KillMode = "mixed";
    };
  };

  # чистка 1-го и 15-го числа; сама поднимает демон через сокет, пропущенный запуск догоняется на загрузке
  systemd.user.services.docker-prune = {
    description = "Docker prune (rootless)";
    unitConfig.ConditionUser = dockUser;
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${dockdevDocker} system prune -f --filter until=336h";
      Nice = 19;
      IOSchedulingClass = "idle";
    };
  };

  systemd.user.timers.docker-prune = {
    wantedBy = [ "timers.target" ];
    unitConfig.ConditionUser = dockUser;
    timerConfig = {
      OnCalendar = "*-*-01,15 03:00";
      Persistent = true;
    };
  };

  # ssh-agent из gcr включён для всех пользователей, dockdev он не нужен
  systemd.user.sockets.gcr-ssh-agent.unitConfig.ConditionUser = "!${dockUser}";
  systemd.user.services.gcr-ssh-agent.unitConfig.ConditionUser = "!${dockUser}";

  systemd.tmpfiles.rules = [
    "d ${projects} 2770 ${user} devshare -"
    # без «+»: существующий каталог ~/projects не трогаем, переносится вручную
    "L ${projectsLink} - - - - ${projects}"
    # прямые записи для обоих пользователей: внутри контейнера supplementary-группы теряются
    "a+ ${projects} - - - - u:${dockUser}:rwx,u:${user}:rwx,g:devshare:rwx,m::rwx,d:u:${dockUser}:rwx,d:u:${user}:rwx,d:g:devshare:rwx,d:m::rwx"
  ];
}

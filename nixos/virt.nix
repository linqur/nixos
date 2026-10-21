{ pkgs, user, ... }:

# QEMU/KVM через libvirt в session-режиме под отдельным пользователем virtjail.
# Демон стартует лениво: systemd держит сокет, virtqemud поднимается при подключении
# virt-manager/virsh и завершается через 2 минуты после последней VM.
let
  virtUser = "virtjail";
  home = "/var/lib/${virtUser}";
  # и сокет, и XDG_RUNTIME_DIR демона; linqur проходит сюда через группу virtshare
  runDir = "/run/${virtUser}";
  sock = "${runDir}/virtqemud-sock";
  # без "+unix": с явным транспортом virt-manager считает хост удалённым
  # и не берёт экран VM через дескриптор (OpenGraphicsFD); транспорт unix и так по умолчанию
  uri = "qemu:///session?socket=${sock}";
  # общий каталог linqur и virtjail: ISO в iso/, остальное — папки для virtiofs и прочего обмена
  virtDir = "/srv/virt";
  virtLink = "/home/${user}/virt";
  # наследуемые права на запись обоим: файлы, созданные virtjail (VM, virtiofs), остаются редактируемыми для linqur и наоборот
  virtAcl = "u:${virtUser}:rwx,u:${user}:rwx,g:virtshare:rwx,m::rwx,d:u:${virtUser}:rwx,d:u:${user}:rwx,d:g:virtshare:rwx,d:m::rwx";
  # share/ открыт всем и по наследству: гостевые uid через virtiofs (300000+) в ACL не перечислены, пишут как «other»
  shareAcl = "${virtAcl},o::rwx,d:o::rwx";
  # стабильный путь: libvirt записывает пути к qemu и прошивке в XML VM,
  # путь в /nix/store сломал бы VM после обновления и сборки мусора
  profile = "/etc/profiles/per-user/${virtUser}";

  qemu = pkgs.qemu_kvm; # только x86_64, без эмуляции других архитектур

  # дескрипторы UEFI-прошивок QEMU с путями через профиль
  firmware = pkgs.runCommand "virtjail-qemu-firmware" { } ''
    mkdir $out
    for f in ${qemu}/share/qemu/firmware/*.json; do
      sed 's|${qemu}/share/qemu/|${profile}/share/qemu/|' "$f" > $out/$(basename "$f")
    done
  '';

  vhostUser = pkgs.runCommand "virtjail-qemu-vhost-user" { } ''
    mkdir $out
    sed 's|${pkgs.virtiofsd}/bin/|${profile}/bin/|' \
      ${pkgs.virtiofsd}/share/qemu/vhost-user/50-virtiofsd.json > $out/50-virtiofsd.json
  '';

  virtqemudConf = pkgs.writeText "virtqemud.conf" ''
    unix_sock_dir = "${runDir}"
    # доступ к сокету решают его права (группа virtshare), polkit не нужен
    auth_unix_rw = "none"
  '';

  qemuConf = pkgs.writeText "qemu.conf" ''
    # при выключении хоста: штатное выключение гостей, по таймауту — poweroff
    # сохранение RAM на диск выключено: лишние гигабайты записи на NVMe
    auto_shutdown_try_save = "none"
    auto_shutdown_try_shutdown = "all"
    auto_shutdown_poweroff = "all"
    auto_shutdown_wait = 60
    # не поднимать выключенные так VM при следующем старте демона
    auto_shutdown_restore = 0
  '';
in
{
  users.groups.${virtUser} = { };
  users.groups.virtshare.members = [ user virtUser ];

  users.users.${virtUser} = {
    isSystemUser = true;
    group = virtUser;
    inherit home;
    # virtiofsd отображает uid гостя в этот диапазон; userborn сам не выдаёт, /etc/subuid собирается в init.nix
    subUidRanges = [{ startUid = 300000; count = 65536; }];
    subGidRanges = [{ startGid = 300000; count = 65536; }];
    packages = [ qemu pkgs.swtpm pkgs.passt pkgs.virtiofsd ];
  };

  # прошивки и vhost-user из профиля virtjail
  environment.pathsToLink = [ "/share/qemu" ];

  systemd.sockets.virtjail-qemud = {
    description = "libvirt QEMU session socket (virtjail, lazy)";
    wantedBy = [ "sockets.target" ];
    socketConfig = {
      ListenStream = sock;
      SocketUser = virtUser;
      SocketGroup = "virtshare";
      SocketMode = "0660";
      # virtqemud забирает сокет от systemd по этому имени
      FileDescriptorName = "virtqemud.socket";
    };
  };

  # системный юнит, а не user: не нужен linger, есть системная D-Bus для PrepareForShutdown от logind,
  # и при выключении хоста демон останавливается до D-Bus и успевает выключить гостей
  systemd.services.virtjail-qemud = {
    description = "libvirt QEMU session daemon (virtjail)";
    requires = [ "virtjail-qemud.socket" ];
    after = [ "dbus.service" ];
    # newuidmap для virtiofsd; qemu, swtpm, passt — по стабильному пути профиля
    path = [ "/run/wrappers" profile ];
    environment = {
      HOME = home;
      XDG_RUNTIME_DIR = runDir;
    };
    # switch не трогает запущенные VM
    restartIfChanged = false;
    serviceConfig = {
      Type = "notify";
      User = virtUser;
      Group = virtUser;
      ExecStart = "${pkgs.libvirt}/sbin/virtqemud --config ${virtqemudConf} --timeout 120";
      # qemu, passt, swtpm и автозапущенные virtlogd/virtstoraged живут в этом же cgroup
      KillMode = "process";
      # побег из QEMU не даёт доступа к /home даже при ошибке в правах
      ProtectHome = true;
      ProtectSystem = "strict";
      ReadWritePaths = [ home runDir virtDir ];
      PrivateTmp = true;
    };
  };

  systemd.tmpfiles.rules = [
    "d ${home} 0700 ${virtUser} ${virtUser} -"
    "d ${home}/.config 0700 ${virtUser} ${virtUser} -"
    "d ${home}/.config/libvirt 0700 ${virtUser} ${virtUser} -"
    "d ${home}/.config/qemu 0700 ${virtUser} ${virtUser} -"
    "L+ ${home}/.config/libvirt/qemu.conf - - - - ${qemuConf}"
    "L+ ${home}/.config/qemu/firmware - - - - ${firmware}"
    "L+ ${home}/.config/qemu/vhost-user - - - - ${vhostUser}"
    "d ${runDir} 0750 ${virtUser} virtshare -"
    "d ${virtDir} 2770 ${user} virtshare -"
    "d ${virtDir}/iso 2770 ${user} virtshare -"
    "d ${virtDir}/share 2777 ${user} virtshare -"
    "L ${virtLink} - - - - ${virtDir}"
    # iso/ создаётся раньше, чем родитель получает default ACL, поэтому права ставятся обоим явно
    "a+ ${virtDir} - - - - ${virtAcl}"
    "a+ ${virtDir}/iso - - - - ${virtAcl}"
    "a+ ${virtDir}/share - - - - ${shareAcl}"
  ];

  home-manager.users.${user} = {
    home.packages = [ pkgs.virt-manager pkgs.libvirt ]; # libvirt ради virsh
    # virsh без -c
    home.sessionVariables.LIBVIRT_DEFAULT_URI = uri;
    # единственное подключение virt-manager; демон поднимается только при открытии virt-manager
    dconf.settings."org/virt-manager/virt-manager/connections" = {
      autoconnect = [ uri ];
      uris = [ uri ];
    };
  };
}

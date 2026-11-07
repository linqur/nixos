{ config, lib, pkgs, user, ... }:

# Виртуальные устройства ввода (uinput): сессия linqur их не принимает никогда, остальные пользователи — общий пул.
# Создателя uinput-устройства ядро не хранит, имя и VID/PID задаёт сам создатель — поэтому правило не разбирает,
# чьё устройство, а закрывает все: niri их не видит, ACL linqur не выдаётся, кнопки питания не срабатывают.
# Создавать и читать может группа uinput; между собой её участники не изолированы (принятый риск, см. tasks/virtual-input.md)
let
  group = "uinput";

  # 72-: после 70-uaccess (виртуальный геймпад получает там uaccess) и до 73-seat-late (выдаёт по нему ACL)
  rules = pkgs.writeTextDir "lib/udev/rules.d/72-virtual-input.rules" ''
    ACTION=="remove", GOTO="virtual_input_end"
    SUBSYSTEM!="input", GOTO="virtual_input_end"
    # /devices/virtual/input/mice — общий узел всех мышей, не uinput; uhid лежит в /devices/virtual/misc и сюда не попадает
    DEVPATH!="/devices/virtual/input/input*", GOTO="virtual_input_end"

    # журнал для настройки: что создаётся и под каким именем (имя задаёт создатель, ему не верим)
    ACTION=="add", KERNEL=="input*", RUN+="${pkgs.util-linux}/bin/logger -t virtual-input -- add %k name=$attr{name} id=$attr{id/bustype}:$attr{id/vendor}:$attr{id/product}"

    # niri (libinput) пропускает устройство; несуществующий seat — второй замок: libinput и logind seat0 его не берут
    ENV{LIBINPUT_IGNORE_DEVICE}="1"
    ENV{ID_SEAT}="seat-virtual"
    # uaccess дал бы ACL активной сессии (linqur), power-switch — logind выключение и сон по KEY_POWER/KEY_SLEEP
    TAG-="uaccess"
    TAG-="power-switch"
    KERNEL=="event*|js*", GROUP="${group}", MODE="0660"

    LABEL="virtual_input_end"
  '';

  # модули nixpkgs, которые создают виртуальный ввод для сессии linqur (часто демоном от root — группа не поможет):
  # с этим правилом они не работают. Появится нужная — решать отдельно (проверка создателя через eBPF)
  virtualInputOptions = [
    [ "hardware" "steam-hardware" ] # uaccess на /dev/uinput — linqur получил бы право создавать
    [ "programs" "steam" ]
    [ "programs" "ydotool" ]
    [ "programs" "weylus" ]
    [ "programs" "xppen" ]
    [ "programs" "mouse-actions" ]
    [ "services" "keyd" ]
    [ "services" "kanata" ]
    [ "services" "kmonad" ]
    [ "services" "input-remapper" ]
    [ "services" "evremap" ]
    [ "services" "evdevremapkeys" ]
    [ "services" "persistent-evdev" ]
    [ "services" "interception-tools" ]
    [ "services" "sunshine" ]
    [ "services" "crossmacro" ]
  ];
  enabled = path: lib.attrByPath (path ++ [ "enable" ]) false config;

  inGroup = g: lib.elem g config.users.users.${user}.extraGroups || lib.elem user (config.users.groups.${g}.members or [ ]);
in
{
  # модуль uinput, группа и /dev/uinput root:uinput 0660; участников группы задают модули программ
  hardware.uinput.enable = true;

  services.udev.packages = [ rules ];

  assertions = [
    {
      assertion = !(inGroup group);
      message = "${user} не должен быть в группе ${group}: право создавать uinput — ввод в любую сессию, что его примет";
    }
    {
      # input читает все устройства, в том числе физическую клавиатуру
      assertion = !(inGroup "input");
      message = "${user} не должен быть в группе input";
    }
    {
      # 16 — только sync (значение systemd); с полным SysRq виртуальная клавиатура перезагружает машину
      assertion = lib.elem (config.boot.kernel.sysctl."kernel.sysrq" or 16) [ 0 16 ];
      message = "kernel.sysrq: виртуальная клавиатура из группы ${group} сможет им пользоваться";
    }
  ] ++ map (path: {
    assertion = !(enabled path);
    message = "${lib.concatStringsSep "." path} создаёт виртуальный ввод, а virtual-input.nix закрывает его для ${user}";
  }) virtualInputOptions;
}

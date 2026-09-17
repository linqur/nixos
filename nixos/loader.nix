{ config, pkgs, ... }:

let
  # Свой установщик UKI на ESP (scripts/src/uki-install, схема — tasks/uki.md).
  # Бинарь статический (musl), собран и закоммичен в scripts/uki-install —
  # здесь только копируем его в store. Откат на старый коммит берёт свою версию.
  uki-install = pkgs.runCommandLocal "uki-install" { } ''
    install -Dm755 ${../scripts/uki-install} $out/bin/uki-install
  '';
  # Отдельная сборка systemd с ukify. В systemPackages её нет сознательно:
  # иначе её systemctl и прочее могли бы перекрыть системные в sw/bin.
  ukify = pkgs.systemdUkify;
in
{
  # Без меню и без systemd-boot: на каждый switch/boot UKI поколения
  # собирается, подписывается и кладётся в \EFI\BOOT\BOOTX64.EFI.
  # NVRAM не трогается никогда — запись «NixOS» создаёт install.sh.
  boot.loader.external.enable = true;
  boot.loader.external.installHook = "${uki-install}/bin/uki-install";

  # Всё, что uki-install получает от Nix, — одним блоком в $toplevel/boot.json
  # рядом с org.nixos.bootspec.v1. Пути интерполируются, поэтому пакеты входят
  # в closure поколения: они есть на диске после nixos-install, а mark-good
  # берёт их из загрузившегося поколения. Цикла нет: ни один путь
  # не зависит от toplevel.
  boot.bootspec.extensions."io.github.linqur.uki" = {
    ukify = "${ukify}/bin/ukify";
    # stub из той же сборки, что и ukify: версии гарантированно совпадают
    stub = "${ukify}/lib/systemd/boot/efi/linuxx64.efi.stub";
    sbctl = "${pkgs.sbctl}/bin/sbctl";
    # sbctl verify проверяет только ESP целиком, отдельный файл — sbverify
    sbverify = "${pkgs.sbsigntool}/bin/sbverify";
    # тот же файл, что станет /etc/os-release поколения; из него секция .osrel
    osRelease = "${config.environment.etc."os-release".source}";
    efiSysMountPoint = config.boot.loader.efi.efiSysMountPoint;
  };

  # Копия загрузившегося BOOTX64.EFI в last-good.efi. multi-user.target —
  # признак удачной загрузки; boot-complete.target не годится: без условий он
  # достигается сразу после sysinit.target. Если загрузились не из BOOTX64
  # (last-good, обрыв установки) или уже отмечено, uki-install ничего не делает.
  systemd.services.uki-mark-good = {
    description = "Mark booted UKI as last-good";
    wantedBy = [ "multi-user.target" ];
    after = [ "multi-user.target" ];
    unitConfig = {
      # After= только порядок: без Requisite юнит запускается и после
      # упавшего multi-user.target (Requires= не прошёл) и отмечает сломанное
      Requisite = [ "multi-user.target" ];
      RequiresMountsFor = config.boot.loader.efi.efiSysMountPoint;
    };
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${uki-install}/bin/uki-install mark-good";
    };
  };

  # sbctl status / verify руками
  environment.systemPackages = [ pkgs.sbctl ];
}

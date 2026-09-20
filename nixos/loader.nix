{ config, pkgs, ... }:
let
  # Свой установщик UKI на ESP (см. scripts/cmd/uki-install). Собирается
  # из исходников, а не берётся готовым бинарём: так он воспроизводим
  # из git + Nix и входит в closure поколения вместе со своей версией.
  uki-install = pkgs.buildGoModule {
    pname = "uki-install";
    version = "0";
    # Flake видит только файлы под git, поэтому локальный scripts/bin/
    # в сборку не попадает.
    src = ../scripts;
    # Только stdlib, зависимостей нет — хеш вендоринга не нужен.
    vendorHash = null;
    subPackages = [ "cmd/uki-install" ];
  };
in
{
  boot.loader.external.enable = true;
  boot.loader.external.installHook = "${uki-install}/bin/uki-install";

  # Всё, что uki-install получает от Nix, — одним блоком. Попадает в
  # $toplevel/boot.json рядом с секцией org.nixos.bootspec.v1, установщик
  # читает только его и не лезет ни в PATH, ни во внутренности toplevel.
  # Пути интерполируются, поэтому пакеты входят в closure поколения: они
  # есть на диске после nixos-install, а откат берёт версии своего
  # поколения. Цикла нет: ни один из путей не зависит от toplevel.
  boot.bootspec.extensions."io.github.linqur.uki" = {
    # Отдельная сборка systemd с ukify. В systemPackages её нет
    # сознательно: иначе её systemctl и прочее могли бы перекрыть
    # системные в sw/bin.
    ukify = "${pkgs.systemdUkify}/bin/ukify";
    # Stub из той же сборки, что и ukify: версии гарантированно совпадают,
    # даже если systemd.package когда-нибудь переопределят.
    stub = "${pkgs.systemdUkify}/lib/systemd/boot/efi/linuxx64.efi.stub";
    sbctl = "${pkgs.sbctl}/bin/sbctl";
    # Тот же файл, что станет /etc/os-release поколения. Из него stub
    # берёт имя и версию для секции .osrel.
    osRelease = "${config.environment.etc."os-release".source}";
  };
}

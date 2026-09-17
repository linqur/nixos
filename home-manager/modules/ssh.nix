{ pkgs, ... }:

{
  programs.ssh.enableDefaultConfig = false;

  # home-manager создаёт ~/.ssh с 755, ssh же ожидает закрытый каталог
  systemd.user.tmpfiles.rules = [ "z %h/.ssh 0700 - - -" ];

  # Дефолтный ключ создаётся один раз при первом входе. Пока файл существует, юнит пропускается,
  # поэтому rebuild ключ не трогает. Чтобы сгенерировать заново — удалить ~/.ssh/id_ed25519*.
  systemd.user.services.ssh-keygen-default = {
    Unit = {
      Description = "Generate default SSH key if missing";
      ConditionPathExists = "!%h/.ssh/id_ed25519";
    };
    Service = {
      Type = "oneshot";
      # пустая passphrase: ключ можно позже защитить через ssh-keygen -p
      ExecStart = "${pkgs.openssh}/bin/ssh-keygen -t ed25519 -N '' -C %u@%H -f %h/.ssh/id_ed25519";
    };
    Install.WantedBy = [ "default.target" ];
  };
}

{
  disko.devices = {
    disk = {
      master = {
        type = "disk";
        device = "/dev/vda";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              type = "EF00";
              size = "1G";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ 
                  "umask=0077" 
                ];
                extraArgs = [
                  "-F" "32"
                ];
              };
            };
            
            encryptedRoot = {
              size = "100%";
              content = {
                type = "luks";
                name = "root";
                extraFormatArgs = [
                  "--type" "luks2"
                  "--cipher" "aes-xts-plain64" # имеет аппаратное ускорение на x86
                  "--key-size" "512"
                  # защита от брутфорса 
                  # второй рекомендованный профиль по RFC 9106
                  # при пароле в 160бит расшифровывется ~40мс, вместо 1-2 секунд поумолчанию
                  # при пароле в 160бит брутфоорс стоставляет время жизни вселенной
                  "--pbkdf" "argon2id"
                  "--pbkdf-parallel" "4"
                  "--pbkdf-memory" "65536"
                  "--pbkdf-force-iterations" "3"
                  # защита от брутфорса
                  "--sector-size" "4096" # лучший размер для блочных носителей сегодня
                  "--use-urandom"
                ];
                initrdUnlock = true; # прокидывать в nix device с настройками
                settings.allowDiscards = true; # разрешать trim сквозь LUKS
                settings.bypassWorkqueues = true; # отключение очередей 
                askPassword = true;
                content = {
                  type = "filesystem";
                  format = "ext4";
                  mountOptions = [ 
                    "noatime" 
                    "lazytime"
                    "commit=15"
                    "errors=remount-ro"
                    "data=ordered"
                  ];
                  extraArgs = [
                    "-m" "1"
                    "-E" "lazy_itable_init=0,lazy_journal_init=0,discard"
                    "-O" "fast_commit"
                    "-b" "4096"
                  ];
                  mountpoint = "/";
                };
              };
            };
          };
        };
      };
    };
  };
}
{ pkgs, user, ... }:

{
  users = {
    defaultUserShell = pkgs.bash;
    # позволяет мутировать пользователя, нужно чтобы установить свой пароль, который не слетит после rebuild
    mutableUsers = true; 

    users.${user} = {
      isNormalUser = true;
      extraGroups = [ "wheel" "networkmanager" ];
      # тот же диапазон, что раньше выдавал update-users-groups.pl (userborn сам не выдаёт)
      subUidRanges = [{ startUid = 100000; count = 65536; }];
      subGidRanges = [{ startGid = 100000; count = 65536; }];
    };
  };
}
{ pkgs, ... }:

{
  users = {
    defaultUserShell = pkgs.bash;
    # позволяет мутировать пользователя, нужно чтобы установить свой пароль, который не слетит после rebuild
    mutableUsers = true; 

    users.linqur = {
      isNormalUser = true;
      extraGroups = [ "wheel" "networkmanager" "docker" ];
    };
  };
}
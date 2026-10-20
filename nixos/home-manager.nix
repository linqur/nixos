{ config, pkgs, inputs, user, homeStateVersion, unstable, ... }:

let
  hm = config.home-manager.users.${user};
in
{
  imports = [ inputs.home-manager.nixosModules.default ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    extraSpecialArgs = { inherit user homeStateVersion inputs unstable; };
    users.${user} = import ../home-manager/home.nix;
  };

  # Активация только при смене поколения, а не на каждой загрузке (~1.7 с на пути к логину).
  # Ссылки в ~ переживают перезагрузку; подменённый файл вернёт rebuild или
  # `sudo systemctl start home-manager-${user}` после удаления gcroots/current-home.
  systemd.services."home-manager-${user}".serviceConfig.ExecCondition =
    pkgs.writeShellScript "hm-generation-changed" ''
      [ "$(${pkgs.coreutils}/bin/readlink ${hm.home.homeDirectory}/.local/state/home-manager/gcroots/current-home)" \
        != ${hm.home.activationPackage} ]
    '';
}

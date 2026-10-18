{ inputs, user, homeStateVersion, unstable, ... }: 

{
  imports = [ inputs.home-manager.nixosModules.default ];
  
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    extraSpecialArgs = { inherit user homeStateVersion inputs unstable; };
    users.${user} = import ../home-manager/home.nix;
  };
}
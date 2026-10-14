{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko/latest";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, nixpkgs-unstable, disko, home-manager, ... }@inputs:
  let 
    user = "linqur";
    stateVersion = "26.05";
    system = "x86_64-linux";
  in {
    nixosConfigurations."home-rog" = nixpkgs.lib.nixosSystem {
      inherit system;

      specialArgs = {
        unstable = import nixpkgs-unstable {
          inherit system user stateVersion inputs;
          config.allowUnfree = true;
        };
        enums = import ./lib/enums.nix;
      };

      modules = [
        disko.nixosModules.disko
        ./hosts/home-rog/disko.nix
        ./hosts/home-rog/configuration.nix
      ];
    };

    nixosConfigurations.vm = nixpkgs.lib.nixosSystem {
      inherit system;

      specialArgs = {
        unstable = import nixpkgs-unstable {
          inherit system user stateVersion inputs;
          config.allowUnfree = true;
        };
        enums = import ./lib/enums.nix;
      };

      modules = [
        disko.nixosModules.disko
        ./hosts/vm/disko.nix
        ./hosts/vm/configuration.nix
      ];
    };

    homeConfigurations.${user} = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.${system};
      extraSpecialArgs = {
        inherit user stateVersion inputs;
      };

      modules = [
        ./home-manager/home.nix
      ];
    };
  };
}
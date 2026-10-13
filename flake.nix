{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
  
    disko = {
      url = "github:nix-community/disko/latest";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, nixpkgs-unstable, disko, ... }:
  {
    nixosConfigurations."home-rog" = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";

      specialArgs = {
        unstable = import nixpkgs-unstable {
          system = "x86_64-linux";
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
      system = "x86_64-linux";

      specialArgs = {
        unstable = import nixpkgs-unstable {
          system = "x86_64-linux";
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
  };
}
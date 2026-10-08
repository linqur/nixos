{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    disko = {
      url = "github:nix-community/disko/latest";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, disko, ... }:
    let
      system = "x86_64-linux";
      hostName = "home-rog";
      stateVersion = "26.05";
      userName = "linqur";
    in
    {
      nixosConfigurations.home-rog = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          unstable = import nixpkgs-unstable {
            inherit system;
            config.allowUnfree = true;
          };
        };
        modules = [
          disko.nixosModules.disko
          ./disko.nix
          ./nixos/imports.nix
        ];
      };
    };
}

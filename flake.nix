{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    # только исходники драйвера NVIDIA; закрепить — заменить ветку на rev, см. Readme «NVIDIA»
    nixpkgs-nvidia.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko/latest";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # тулчейн Rust с выбранными целями (musl и др.); в rustc из nixpkgs только std хоста
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    llm-agents = {
      url = "github:numtide/llm-agents.nix";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
  };

  outputs = { nixpkgs, nixpkgs-unstable, disko, ... }@inputs:
  let
    user = "linqur";
    stateVersion = "26.05";
    homeStateVersion = "26.05";
    system = "x86_64-linux";
    enums = import ./lib/enums.nix;

    unstable = import nixpkgs-unstable {
      inherit system;
      config.allowUnfree = true;
    };

    # хост — каталог hosts/<host>: профиль железа, разметка диска, имя.
    # Профиль попадает в модули аргументом `profile`, см. «Хосты и профили» в Readme.md
    mkHost = host: nixpkgs.lib.nixosSystem {
      inherit system;

      specialArgs = {
        inherit user stateVersion homeStateVersion inputs unstable enums;
        profile = import ./hosts/${host}/profile.nix { inherit enums; };
      };

      modules = [
        disko.nixosModules.disko
        ./hosts/${host}/disko.nix
        ./hosts/${host}/configuration.nix
      ];
    };
  in {
    nixosConfigurations = {
      vm = mkHost "vm";
      vm-minimal = mkHost "vm-minimal";
      home-rog-usb-hp = mkHost "home-rog-usb-hp";
      home-rog = mkHost "home-rog";
    };
  };
}
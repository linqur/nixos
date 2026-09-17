# Настройки nixd: что вычислять для подсказок и переходов к определению. Общие для VS Code и Helix
{ homeDirectory, hostName }:

let
  # flake из рабочей копии, а не из /nix/store — опции видны сразу после правки, без пересборки
  flake = ''(builtins.getFlake "${homeDirectory}/nixos")'';
  host = "${flake}.nixosConfigurations.${hostName}";  # имя хоста совпадает с именем конфигурации во flake.nix
in

{
  nixpkgs.expr = "import ${flake}.inputs.nixpkgs { }";  # pkgs.* — тот же nixpkgs, что в flake.lock
  options = {                                           # переход от имени опции к её объявлению
    nixos.expr = "${host}.options";
    home-manager.expr = "${host}.options.home-manager.users.type.getSubOptions [ ]";  # home-manager — модуль NixOS, отдельной конфигурации нет
  };
}

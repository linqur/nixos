{ pkgs, ... }:

let
  lsg = pkgs.writeShellApplication {
    name = "lsg";
    runtimeInputs = [ pkgs.eza ];
    text = builtins.readFile ../../scripts/lsg.sh;
  };
in
{
  home.packages = [ lsg ];

  # Алиасы из programs.eza отключены в eza.nix
  programs.bash.shellAliases = {
    ls = "lsg";
    ll = "lsg -l";
    la = "lsg -a";
    lla = "lsg -la";
    lt = "eza --tree";
  };
}

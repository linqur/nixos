{ config, pkgs, ... }:

{
  # rustup не нужен: тулчейн (cargo, rustc, clippy, rustfmt, rust-analyzer) — pkgs.rustToolchain, см. nixos/rust.nix
  home.packages = with pkgs; [
    gcc  # cc — драйвер линковки для rustc и build.rs (пути к glibc, crt*.o)
    rustToolchain
  ];

  # ~/.local/share/cargo вместо ~/.cargo (реестр крейтов, cargo install)
  home.sessionVariables.CARGO_HOME = "${config.xdg.dataHome}/cargo";
}

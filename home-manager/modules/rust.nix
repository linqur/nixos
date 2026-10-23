{ config, pkgs, ... }:

{
  # rustup не нужен: версия тулчейна задаётся nixpkgs и совпадает с rust-analyzer
  home.packages = with pkgs; [
    cargo
    clippy  # rust-analyzer в VS Code проверяет через clippy
    gcc  # cc — драйвер линковки для rustc и build.rs (пути к glibc, crt*.o)
    rustc
    rustfmt
  ];

  # ~/.local/share/cargo вместо ~/.cargo (реестр крейтов, cargo install)
  home.sessionVariables.CARGO_HOME = "${config.xdg.dataHome}/cargo";
}

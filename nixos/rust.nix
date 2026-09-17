{ inputs, ... }:

{
  # Тулчейн Rust — официальные сборки rust-lang.org через rust-overlay, версия в flake.lock.
  # В rustc из nixpkgs только std хоста (gnu), без musl статический бинарь не собрать.
  # Один пакет pkgs.rustToolchain: home.packages и редакторы берут его, rust-analyzer совпадает с rustc
  nixpkgs.overlays = [
    inputs.rust-overlay.overlays.default
    (final: _: {
      rustToolchain = final.rust-bin.stable.latest.default.override {
        targets = [
          "x86_64-unknown-linux-gnu"   # обычные бинари хоста
          "x86_64-unknown-linux-musl"  # статические, без внешних библиотек: scripts/*
        ];
        extensions = [
          "rust-src"       # исходники std: переходы и подсказки rust-analyzer
          "rust-analyzer"
        ];
      };
    })
  ];
}

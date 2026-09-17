{ config, ... }:

{
  programs.go = {
    env = {
      GOPATH = "${config.xdg.dataHome}/go";  # ~/.local/share/go вместо ~/go
      GOTOOLCHAIN = "local";  # только go из Nix: не скачивать другие версии по директиве toolchain в go.mod
    };
    telemetry.mode = "off";  # по умолчанию "local": счётчики пишутся на диск
  };
}

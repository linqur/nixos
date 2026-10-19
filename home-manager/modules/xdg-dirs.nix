{ config, lib, ... }:

let
  # Папки, пути которых нельзя поменять настройкой: ~/имя -> каталог по XDG
  # Подпапки dot-* отделяют их от остального содержимого родительских каталогов
  links = {
    ".mozilla" = "${config.xdg.configHome}/mozilla/.mozilla";           # только native-messaging-hosts
    ".vscode" = "${config.xdg.dataHome}/vscode/.vscode";                # расширения и argv.json
    ".vscode-shared" = "${config.xdg.dataHome}/vscode/.vscode-shared";
  };

  mkLink = name: target: ''
    run mkdir -p $VERBOSE_ARG "${target}"
    run ln -sfn $VERBOSE_ARG "${target}" "$HOME/${name}"
  '';
in
{
  # Выполняется только при switch, до записи home.file, чтобы расширения vscode
  # и native-messaging-hosts сразу попали в XDG-каталоги через симлинк
  home.activation.xdgDirSymlinks = lib.hm.dag.entryBefore [ "checkLinkTargets" ]
    (lib.concatStringsSep "\n" (lib.mapAttrsToList mkLink links));
}

{ config, lib, pkgs, unstable, ... }:

# Discord через Vesktop (Vencord). Запуск через fuzzel, без автозапуска; закрытие окна прячет в трей.
# Vesktop и Vencord пишут свои настройки сами, поэтому файлы — копии, а не ссылки в store:
# правка мышкой живёт до следующего switch (как у Thunar). Понравившийся плагин — перенести сюда
let
  cfg = config.programs.vesktop;
  n = import ../../lib/nord.nix;
  json = pkgs.formats.json { };
  dir = "${config.xdg.configHome}/vesktop";

  # путь относительно dir → сгенерированный файл; модуль HM положил бы их ссылками только для чтения
  writable = {
    "settings.json" = json.generate "vesktop-settings" cfg.settings;
    "settings/settings.json" = json.generate "vencord-settings" cfg.vencord.settings;
  };

  # мастер первого запуска переписал бы minimizeToTray и arRPC
  state = json.generate "vesktop-state" { firstLaunch = false; };

  # приглушённое — смесь текста с фоном: nord3 на nord0 почти не читается
  muted = "color-mix(in srgb, ${n.nord4} 65%, ${n.nord0})";
in
{
  programs.vesktop = {
    # Vencord из nixpkgs, версия в flake.lock; на unstable исправления после поломок Discord приходят быстрее
    package = unstable.vesktop;
    vencord.useSystem = true;

    # ключи: https://github.com/Vencord/Vesktop/blob/main/src/shared/settings.d.ts
    settings = {
      discordBranch = "stable";
      tray = true;
      minimizeToTray = true; # закрыть окно — в трей, звонок не рвётся; выход — из меню трея
      hardwareAcceleration = true; # рисует Intel; dGPU не нужна даже для Activities
      # Vesktop сам запоминает цвета темы для заставки при выходе; задаём, чтобы switch их не сбрасывал
      splashColor = n.nord4;
      splashBackground = n.nord0;
    };

    vencord.settings = {
      # версией управляет Nix
      autoUpdate = false;
      autoUpdateNotification = false;
      notifyAboutUpdates = false;

      enabledThemes = [ "nord.css" ];

      # только убирающие лишнее; без обхода ограничений Discord
      plugins = lib.genAttrs [
        "AlwaysTrust" # без окна «вы покидаете Discord» у ссылок
        "BetterSettings" # настройки без полноэкранной анимации
        "ClearURLs" # вырезает трекинговые параметры из ссылок
        "DisableCallIdle" # не выкидывает из звонка за бездействие
        "NoF1" # F1 не открывает справку
        "NoOnboardingDelay"
        "NoProfileThemes" # чужие профили без своих цветов, в теме Nord
        "NoReplyMention" # ответ без @-пинга автора
        "NoTypingAnimation"
        "VolumeBooster" # громкость собеседника выше 200%
      ] (_: { enabled = true; });
    };

    # Переменные Discord (visual refresh), действует в тёмной теме — выбрать в Настройки → Внешний вид.
    # Discord переименовывает переменные; после обновления что-то может снова стать серым — поправить здесь
    vencord.themes.nord = ''
      .theme-dark, .theme-darker, .theme-midnight {
        --background-base-lowest: ${n.nord0} !important;
        --background-base-lower: ${n.nord0} !important;
        --background-base-low: ${n.nord1} !important;
        --background-surface-high: ${n.nord1} !important;
        --background-surface-higher: ${n.nord2} !important;
        --background-surface-highest: ${n.nord2} !important;
        --chat-background-default: ${n.nord0} !important;
        --card-background-default: ${n.nord1} !important;
        --message-background-hover: ${n.nord1} !important;
        --background-mod-subtle: color-mix(in srgb, ${n.nord2} 40%, transparent) !important;
        --background-mod-normal: color-mix(in srgb, ${n.nord2} 70%, transparent) !important;
        --background-mod-strong: ${n.nord2} !important;

        --text-default: ${n.nord4} !important;
        --text-strong: ${n.nord6} !important;
        --text-muted: ${muted} !important;
        --text-subtle: ${muted} !important;
        --text-link: ${n.nord8} !important;
        --text-brand: ${n.nord8} !important;
        --channels-default: ${muted} !important;
        --interactive-icon-default: ${muted} !important;
        --interactive-icon-hover: ${n.nord5} !important;
        --interactive-icon-active: ${n.nord6} !important;
        --interactive-muted: ${n.nord3} !important;

        --brand-500: ${n.nord10} !important;
        --border-subtle: ${n.nord1} !important;
        --border-focus: ${n.nord8} !important;
        --input-background-default: ${n.nord1} !important;
        --input-border-default: ${n.nord2} !important;

        --status-danger: ${n.nord11} !important;
        --text-feedback-critical: ${n.nord11} !important;
        --status-warning: ${n.nord13} !important;
        --status-positive: ${n.nord14} !important;
      }
    '';
  };

  home.file = lib.mapAttrs' (p: _: lib.nameValuePair "${dir}/${p}" { enable = lib.mkForce false; }) writable;

  home.activation.vesktopSettings = lib.mkIf cfg.enable (lib.hm.dag.entryAfter [ "linkGeneration" ] (
    lib.concatStrings (lib.mapAttrsToList (p: src: ''
      run install -D -m 644 ${src} ${lib.escapeShellArg "${dir}/${p}"}
    '') writable)
    + ''
      [ -e ${lib.escapeShellArg "${dir}/state.json"} ] \
        || run install -D -m 644 ${state} ${lib.escapeShellArg "${dir}/state.json"}
    ''
  ));
}

{ config, pkgs, unstable, ... }:

let
  code = "${config.programs.vscode.package}/bin/code";
in

{
  programs.vscode = {
    package = unstable.vscode;  # расширение code-spell-checker-russian требует VS Code >= 1.125
    mutableExtensionsDir = false;  # расширения только из Nix: Marketplace не ставит и не обновляет их сам

    # --- Флаги запуска (~/.vscode/argv.json) ---
    argvSettings = {
      "enable-crash-reporter" = false;  # не отправлять отчёты о падениях; иначе VS Code пишет crash-reporter-id в read-only файл
      # аппаратное ускорение не трогаем: без GPU отрисовка ляжет на CPU
      # Wayland включается сам (Electron выбирает ozone-platform=wayland), NIXOS_OZONE_WL не нужен
    };

    profiles.default = {
      enableUpdateCheck = false;           # update.mode = "none": VS Code обновляется через Nix
      enableExtensionUpdateCheck = false;  # extensions.autoCheckUpdates = false

      extensions = with pkgs.vscode-extensions; [
        arcticicestudio.nord-visual-studio-code  # официальная тема Nord
        jnoortheen.nix-ide
        golang.go
        rust-lang.rust-analyzer
        streetsidesoftware.code-spell-checker
      ] ++ pkgs.vscode-utils.extensionsFromVscodeMarketplace [
        {
          # русский словарь для spellchecker, в nixpkgs отсутствует
          publisher = "streetsidesoftware";
          name = "code-spell-checker-russian";
          version = "3.0.0";
          sha256 = "06yhxzsd2hrcv32fa28dp77qbckamndyscs8kpvllqjijww50jrs";
        }
      ];

      userSettings = {
        "workbench.colorTheme" = "Nord";
        "editor.fontFamily" = "'JetBrains Mono', monospace";
        "editor.fontSize" = 14;
        "terminal.integrated.fontFamily" = "'JetBrains Mono'";
        "cSpell.language" = "en,ru";
        "go.useLanguageServer" = true;
        "go.alternateTools" = { gopls = "${pkgs.gopls}/bin/gopls"; };  # gopls из Nix, расширение не пытается его скачать
        "rust-analyzer.server.path" = "${pkgs.rust-analyzer}/bin/rust-analyzer";
        "rust-analyzer.server.extraEnv" = { RUST_SRC_PATH = "${pkgs.rustPlatform.rustLibSrc}"; };  # исходники std: в rustc из nixpkgs их нет, без них не работают переходы и подсказки по std

        # --- rust-analyzer ---
        "rust-analyzer.checkOnSave" = true;                 # cargo check при каждом сохранении
        "rust-analyzer.check.command" = "clippy";           # вместо check: больше предупреждений, но дороже
        "rust-analyzer.check.allTargets" = false;           # не проверять тесты, бенчмарки и примеры при каждом сохранении
        "rust-analyzer.cachePriming.enable" = true;         # индексировать зависимости при открытии проекта: переходы к определению быстрее
        "rust-analyzer.cargo.targetDir" = true;             # отдельный target/ для rust-analyzer: cargo build в терминале не сбрасывает его кэш
        "rust-analyzer.procMacro.enable" = true;            # без макросов (serde, tokio) будут ложные ошибки
        "rust-analyzer.cargo.buildScripts.enable" = true;   # без build.rs часть крейтов не разберётся

        # --- Go ---
        "go.vetOnSave" = "off";                             # gopls уже запускает те же анализаторы
        "go.lintOnSave" = "off";                            # не запускать отдельный линтер при каждом сохранении
        "go.testExplorer.enable" = false;                   # не сканировать тесты для панели Testing
        "go.diagnostic.vulncheck" = "Off";                  # проверка уязвимостей ходит в сеть
        "gopls" = {
          "build.directoryFilters" = [ "-**/node_modules" "-**/result" "-**/.direnv" ];  # не загружать эти каталоги как часть проекта
        };

        # --- Орфография (проверяются только открытые файлы, при открытии и правке) ---
        "cSpell.spellCheckDelayMs" = 500;                   # проверять после паузы в наборе, а не на каждую клавишу
        "cSpell.ignorePaths" = [ "**/target/**" "**/result/**" "**/.direnv/**" "**/node_modules/**" "**/*.lock" ];  # не проверять сгенерированное

        # --- Nix (nixd) ---
        "nix.enableLanguageServer" = true;                  # языковой сервер для Nix
        "nix.serverPath" = "${pkgs.nixd}/bin/nixd";         # nixd из Nix, а не из PATH

        # --- Отрисовка и анимации ---
        "workbench.reduceMotion" = "on";                    # без анимаций интерфейса
        "editor.smoothScrolling" = false;                   # без анимации прокрутки редактора
        "workbench.list.smoothScrolling" = false;           # то же для дерева файлов и списков
        "terminal.integrated.smoothScrolling" = false;      # то же для терминала
        "editor.cursorBlinking" = "solid";                  # курсор не мигает, нет перерисовки дважды в секунду
        "editor.cursorSmoothCaretAnimation" = "off";        # курсор перемещается без анимации
        "editor.stickyScroll.enabled" = false;              # не закреплять заголовки функций сверху, они пересчитываются при прокрутке
        "terminal.integrated.stickyScroll.enabled" = false; # то же для команд в терминале
        "editor.folding" = false;                           # отключить сворачивание кода: не считаются диапазоны, нет стрелок на поле
        "editor.renderWhitespace" = "none";                # не рисовать точки на месте пробелов
        "editor.experimentalGpuAcceleration" = "off";       # экспериментальный рендер через WebGPU, пока бывают артефакты
        "terminal.integrated.gpuAcceleration" = "auto";     # терминал рисует видеокарта (WebGL), а не CPU

        # --- Запросы к языковым серверам ---
        "editor.occurrencesHighlight" = "off";              # не подсвечивать слово под курсором: запрос на каждое движение
        "editor.selectionHighlight" = false;                # не подсвечивать совпадения с выделенным
        "editor.codeLens" = false;                          # убрать строки над функциями («N references», «run test»)
        "editor.inlayHints.enabled" = "offUnlessPressed";   # подсказки типов только при зажатых Ctrl+Alt
        "editor.lightbulb.enabled" = "off";                 # убрать лампочку с быстрыми исправлениями
        "breadcrumbs.enabled" = false;                      # убрать строку пути над редактором
        "editor.hover.delay" = 600;                         # всплывающая подсказка при наведении через 600 мс (по умолчанию 300)
        "editor.quickSuggestionsDelay" = 50;                # автодополнение не на каждую клавишу (по умолчанию 10 мс)
        "editor.wordBasedSuggestions" = "off";              # не сканировать открытые файлы ради подсказок по словам

        # --- Отслеживание файлов и поиск ---
        "search.followSymlinks" = false;  # не заходить по симлинкам: result ведёт в /nix/store
        "files.watcherExclude" = {        # не следить за изменениями в служебных и сборочных каталогах
          "**/.git/objects/**" = true;
          "**/.git/subtree-cache/**" = true;
          "**/target/**" = true;
          "**/result/**" = true;
          "**/.direnv/**" = true;
          "**/node_modules/**" = true;
        };
        "search.exclude" = {              # и не искать в них
          "**/target" = true;
          "**/result" = true;
          "**/.direnv" = true;
          "**/node_modules" = true;
        };
        "files.exclude" = {               # и не показывать в дереве файлов
          "**/target" = true;
          "**/result" = true;
          "**/.direnv" = true;
          "**/node_modules" = true;
        };

        # --- Git ---
        "git.autofetch" = false;                        # без фонового git fetch раз в 3 минуты
        "git.autorefresh" = true;                       # статус обновляется сам при изменении файлов
        "git.detectSubmodules" = true;                  # видеть подмодули
        "git.decorations.enabled" = true;               # красить файлы в дереве по статусу git
        "git.openRepositoryInParentFolders" = "never";  # не искать репозиторий в родительских каталогах

        # --- Git открывает редактор в VS Code, если запущен из VS Code (снаружи остаётся EDITOR = hx) ---
        "git.useEditorAsCommitInput" = true;  # из интерфейса: сообщения коммитов, merge, rebase --continue — вкладкой VS Code
        "git.terminalGitEditor" = true;       # во встроенном терминале GIT_EDITOR = VS Code: commit, rebase -i, merge, tag -a
        "git.mergeEditor" = true;             # конфликты открываются в трёхпанельном редакторе слияния
        # git mergetool / difftool во встроенном терминале — через VS Code; GIT_CONFIG_* действуют только в этом терминале
        "terminal.integrated.env.linux" = {
          GIT_CONFIG_COUNT = "5";
          GIT_CONFIG_KEY_0 = "merge.tool";
          GIT_CONFIG_VALUE_0 = "vscode";
          GIT_CONFIG_KEY_1 = "mergetool.vscode.cmd";
          GIT_CONFIG_VALUE_1 = ''${code} --wait --merge "$REMOTE" "$LOCAL" "$BASE" "$MERGED"'';
          GIT_CONFIG_KEY_2 = "mergetool.keepBackup";  # не оставлять *.orig после разрешения конфликта
          GIT_CONFIG_VALUE_2 = "false";
          GIT_CONFIG_KEY_3 = "diff.tool";
          GIT_CONFIG_VALUE_3 = "vscode";
          GIT_CONFIG_KEY_4 = "difftool.vscode.cmd";
          GIT_CONFIG_VALUE_4 = ''${code} --wait --diff "$LOCAL" "$REMOTE"'';
        };

        # --- Сеть и телеметрия ---
        "telemetry.telemetryLevel" = "off";                       # не отправлять Microsoft данные об использовании
        "telemetry.feedback.enabled" = false;                     # убрать кнопки «Отправить отзыв»
        "workbench.enableExperiments" = false;                    # Microsoft не включает эксперименты удалённо
        "workbench.settings.enableNaturalLanguageSearch" = false; # поиск по настройкам не уходит в облако
        "update.showReleaseNotes" = false;                        # не открывать «что нового» после обновления
        "extensions.autoUpdate" = "off";                          # расширения не обновляются сами (строка: false VS Code считает устаревшим и переписывает при каждом запуске)
        "extensions.ignoreRecommendations" = true;                # не предлагать расширения
        "npm.fetchOnlinePackageInfo" = false;                     # не ходить в npm при наведении в package.json
        "workbench.cloudChanges.autoResume" = "off";              # отключить Cloud Changes
        "workbench.cloudChanges.continueOn" = "off";
        "go.toolsManagement.checkForUpdates" = "off";             # расширение Go не проверяет версии инструментов

        # --- Запись на диск ---
        "files.autoSave" = "off";                            # сохранять только вручную
        "files.hotExit" = "off";                             # не сохранять несохранённое в Backups; при закрытии VS Code спросит
        "workbench.localHistory.enabled" = false;            # не хранить копию файла при каждом сохранении
        "terminal.integrated.enablePersistentSessions" = false;  # не сохранять буфер терминала при выходе

        # --- Лишний функционал ---
        "chat.disableAIFeatures" = true;                             # убрать встроенный Copilot/Chat целиком
        "workbench.startupEditor" = "none";                          # без страницы приветствия
        "workbench.welcomePage.walkthroughs.openOnInstall" = false;  # без обучающих туров после установки расширений
        "workbench.tips.enabled" = false;                            # без подсказок в пустом редакторе
        "window.commandCenter" = false;                          # убрать поиск команд из заголовка
        "workbench.layoutControl.enabled" = false;                   # убрать кнопки раскладки из заголовка
        "window.titleBarStyle" = "native";                           # заголовок от niri, а с prefer-no-csd его просто нет
        "security.workspace.trust.enabled" = false;                  # не спрашивать «доверяете ли вы этой папке»
        "go.survey.prompt" = false;                                  # без опросов от расширения Go
        "merge-conflict.codeLens.enabled" = false;                   # без кнопок над конфликтами слияния
      };
    };
  };

  # gopls для расширения Go (go — в go.nix, rustc/cargo — в rust.nix)
  home.packages = [ pkgs.gopls ];
}

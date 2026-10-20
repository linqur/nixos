{ config, pkgs, ... }:

{
  programs.helix = {
    defaultEditor = true;  # EDITOR и VISUAL = hx в сессии пользователя

    # Буфер обмена на Wayland: без wl-copy/wl-paste helix не видит системный буфер
    extraPackages = [ pkgs.wl-clipboard ];

    settings = {
      theme = "nord";  # встроенная тема helix

      editor = {
        bufferline = "multiple";        # вкладки открытых файлов, как в VS Code, когда их больше одного
        color-modes = true;             # режим (NOR/INS/SEL) в статусной строке подсвечен цветом
        cursor-shape.insert = "bar";    # в режиме вставки курсор-черта, как в VS Code
        indent-guides.render = true;    # направляющие отступов, как в VS Code
        file-picker.hidden = false;     # показывать dot-файлы, как дерево файлов VS Code (.gitignore и ignore ниже по-прежнему действуют)
        lsp = {
          display-inlay-hints = false;  # без подсказок типов в строке (в VS Code — только по Ctrl+Alt)
          display-messages = true;      # прогресс индексации rust-analyzer/gopls в статусной строке
        };
      };

      # Ctrl+S сохраняет, как в VS Code
      keys.normal."C-s" = ":write";
      keys.insert."C-s" = [ "normal_mode" ":write" ];
    };

    # ~/.config/helix/ignore: не показывать в выборе файлов и глобальном поиске (files.exclude, search.exclude)
    ignores = [
      ".git/"
      "target/"
      "result"
      ".direnv/"
      "node_modules/"
    ];

    languages = {
      language-server = {
        # --- Nix ---
        nixd.command = "${pkgs.nixd}/bin/nixd";  # nixd из Nix, а не из PATH; nil не нужен

        # --- Go ---
        gopls = {
          command = "${pkgs.gopls}/bin/gopls";
          config."build.directoryFilters" = [ "-**/node_modules" "-**/result" "-**/.direnv" ];  # не загружать эти каталоги как часть проекта
        };

        # --- rust-analyzer ---
        rust-analyzer = {
          command = "${pkgs.rust-analyzer}/bin/rust-analyzer";
          environment.RUST_SRC_PATH = "${pkgs.rustPlatform.rustLibSrc}";  # исходники std: в rustc из nixpkgs их нет, без них не работают переходы и подсказки по std
          config = {
            checkOnSave = true;                # cargo check при каждом сохранении
            check.command = "clippy";          # вместо check: больше предупреждений, но дороже
            check.allTargets = false;          # не проверять тесты, бенчмарки и примеры при каждом сохранении
            cachePriming.enable = true;        # индексировать зависимости при открытии проекта: переходы к определению быстрее
            cargo.targetDir = true;            # отдельный target/ для rust-analyzer: cargo build в терминале не сбрасывает его кэш
            procMacro.enable = true;           # без макросов (serde, tokio) будут ложные ошибки
            cargo.buildScripts.enable = true;  # без build.rs часть крейтов не разберётся
          };
        };

        # --- Орфография (замена cSpell) ---
        # Проверяет комментарии и строки по tree-sitter, английский и русский.
        # Словари скачиваются один раз при первом запуске в ~/.cache/codebook.
        codebook = {
          command = "${pkgs.codebook}/bin/codebook-lsp";
          args = [ "serve" ];
          config.globalConfigPath = "${config.xdg.configHome}/codebook/codebook.toml";
        };
      };

      language = [
        # nixd без nil; codebook не подключён: Nix он не разбирает и проверял бы весь файл как текст
        { name = "nix"; language-servers = [ "nixd" ]; }
        # golangci-lint-lsp не нужен: линтер при сохранении выключен и в VS Code
        { name = "go"; language-servers = [ "gopls" "codebook" ]; }
        # rustfmt при сохранении не запускается, как в VS Code
        { name = "rust"; language-servers = [ "rust-analyzer" "codebook" ]; auto-format = false; }
        { name = "markdown"; language-servers = [ "codebook" ]; }
        { name = "git-commit"; language-servers = [ "codebook" ]; }
      ];
    };
  };

  # Глобальные настройки codebook (cSpell.language = en,ru; cSpell.ignorePaths).
  # Файл только для чтения: «добавить слово» пишет в codebook.toml проекта.
  xdg.configFile."codebook/codebook.toml".source = (pkgs.formats.toml { }).generate "codebook.toml" {
    dictionaries = [ "en_us" "ru" ];
    ignore_paths = [ "**/target/**" "**/result/**" "**/.direnv/**" "**/node_modules/**" "**/*.lock" ];
  };
}

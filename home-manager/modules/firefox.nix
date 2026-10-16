{ pkgs, ... }:

{
  programs.firefox = {
    # --- Телеметрия и лишние сервисы ---
    policies = {
      DisableTelemetry = true;          # не отправлять Mozilla данные об использовании
      DisableFirefoxStudies = true;     # отключить «исследования»: Mozilla иначе может включать у вас эксперименты удалённо
      DisableFirefoxAccounts = true;    # убрать Firefox Sync и аккаунт, если синхронизация не нужна
      DisableFormHistory = true;        # не запоминать то, что вводили в формы и поиск
      DisableProfileImport = true;      # убрать пункт «импорт из другого браузера»
      NoDefaultBookmarks = true;        # не создавать стандартные закладки Mozilla
      DisableFeedbackCommands = true;   # убрать пункты меню «Отправить отзыв» и «Сообщить о сайте»
      DisableAppUpdate = true;          # Firefox сам не обновляется, обновления идут через Nix
      DontCheckDefaultBrowser = true;   # не спрашивать «сделать Firefox браузером по умолчанию?»
      OverrideFirstRunPage = "";        # не открывать страницу приветствия при первом запуске
      OverridePostUpdatePage = "";      # не открывать страницу «что нового» после обновления
      DisableFirefoxScreenshots = true; # убрать встроенные скриншоты
      DisableSystemAddonUpdate = true;  # не обновлять системные расширения Mozilla отдельно от браузера
      PasswordManagerEnabled = false;   # отключить встроенный менеджер паролей
      HttpsOnlyMode = "enabled";        # открывать сайты только по HTTPS, при его отсутствии предупреждать
      EnableTrackingProtection = {
        Value = true;          # включить блокировку трекеров
        Cryptomining = true;   # блокировать скрытый майнинг криптовалют в браузере
      };

      UserMessaging = {
        ExtensionRecommendations = false;  # не предлагать расширения во всплывающих подсказках
        FeatureRecommendations = false;    # не показывать подсказки про новые функции
        UrlbarInterventions = false;       # убрать подсказки в адресной строке вроде «обновите Firefox»
        SkinningWelcome = false;           # убрать приветственную страницу при первом запуске
        MoreFromMozilla = false;           # убрать раздел «Ещё от Mozilla» в настройках
      };

      # --- Страница новой вкладки ---
      FirefoxHome = {
        Search = true;               # оставить поисковую строку
        TopSites = false;            # убрать плитки частых сайтов
        SponsoredTopSites = false;   # убрать рекламные плитки
        Highlights = false;          # убрать блок «недавняя активность»
        Pocket = false;              # убрать рекомендованные статьи
        SponsoredPocket = false;     # убрать рекламные статьи
        Snippets = false;            # убрать сообщения от Mozilla
      };

      ExtensionSettings = {
        "{036a55b4-5e72-4d05-a06c-cba2dfcc134a}" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/traduzir-paginas-web/latest.xpi";
          installation_mode = "force_installed";
        };
        "uBlock0@raymondhill.net" = {   # блокировщик рекламы и трекеров: быстрее страницы, меньше мусора и вредоносной рекламы
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
          installation_mode = "force_installed";
        };
        "ru@dictionaries.addons.mozilla.org" = {   # русский словарь для проверки орфографии (английский встроен)
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/russian-spellchecking-dic-3703/latest.xpi";
          installation_mode = "force_installed";
        };
      };
    };

    profiles.default = {
      isDefault = true;

      # Палитра Nord, как в foot и niri:
      # polar night #2e3440 #3b4252 #434c5e #4c566a, snow storm #d8dee9 #e5e9f0, frost #88c0d0 #81a1c1, red #bf616a
      userChrome = ''
        :root {
          --lwt-accent-color: #2e3440 !important;                   /* фон окна и полосы вкладок */
          --lwt-text-color: #d8dee9 !important;
          --toolbar-bgcolor: #3b4252 !important;                    /* панель с адресной строкой */
          --toolbar-color: #d8dee9 !important;
          --toolbar-field-background-color: #2e3440 !important;     /* адресная строка */
          --toolbar-field-color: #e5e9f0 !important;
          --toolbar-field-focus-background-color: #2e3440 !important;
          --toolbar-field-focus-color: #eceff4 !important;
          --toolbar-field-focus-border-color: #88c0d0 !important;
          --tab-selected-bgcolor: #4c566a !important;               /* активная вкладка */
          --tab-selected-textcolor: #eceff4 !important;
          --tab-loading-fill: #88c0d0 !important;
          --arrowpanel-background: #3b4252 !important;              /* выпадающие меню и панели */
          --arrowpanel-color: #d8dee9 !important;
          --arrowpanel-border-color: #4c566a !important;
          --arrowpanel-dimmed: #434c5e !important;
          --sidebar-background-color: #2e3440 !important;
          --sidebar-text-color: #d8dee9 !important;
          --autocomplete-popup-background: #3b4252 !important;      /* список подсказок */
          --autocomplete-popup-color: #d8dee9 !important;
          --autocomplete-popup-highlight-background: #4c566a !important;
          --autocomplete-popup-highlight-color: #eceff4 !important;
          --focus-outline-color: #88c0d0 !important;
          --toolbarbutton-icon-fill: #d8dee9 !important;            /* иконки кнопок */
        }

        /* Переменные Firefox 155 действуют не везде, поэтому красим основные области напрямую */
        #navigator-toolbox,
        #TabsToolbar,
        #titlebar {
          background-color: #2e3440 !important;
          color: #d8dee9 !important;
        }
        #nav-bar,
        #PersonalToolbar {
          background-color: #3b4252 !important;
          color: #d8dee9 !important;
        }
        #urlbar-background,
        #searchbar {
          background-color: #2e3440 !important;
          border-color: #4c566a !important;
        }
        #urlbar[focused] > #urlbar-background {
          border-color: #88c0d0 !important;
        }
        .tabbrowser-tab {
          color: #d8dee9 !important;
        }
        .tab-background[selected] {
          background-color: #4c566a !important;
        }
        .tabbrowser-tab[selected] {
          color: #eceff4 !important;
        }
        .urlbarView,
        .urlbarView-row[selected] {
          color: #d8dee9 !important;
        }
        .urlbarView {
          background-color: #3b4252 !important;
        }
        .urlbarView-row[selected] {
          background-color: #4c566a !important;
        }
      '';

      userContent = ''
        @-moz-document url-prefix("about:") {
          :root {
            --in-content-page-background: #2e3440 !important;
            --in-content-page-color: #d8dee9 !important;
            --in-content-box-background: #3b4252 !important;
            --in-content-box-border-color: #4c566a !important;
            --in-content-primary-button-background: #88c0d0 !important;
            --in-content-primary-button-text-color: #2e3440 !important;
            --in-content-link-color: #88c0d0 !important;
            --in-content-accent-color: #88c0d0 !important;
          }
        }
      '';
      settings = {
        # --- Проверка орфографии ---
        "layout.spellcheck.default" = 2;                # проверять и однострочные поля, не только многострочные
        "spellchecker.dictionary" = "en-US,ru";         # языки проверки: английский и русский одновременно

        # --- Память и процессы ---
        "dom.ipc.processPreload.enabled" = false;       # не держать заранее запущенный пустой процесс для новой вкладки
        "dom.ipc.processPrelaunch.fission.number" = 0;  # то же для процессов изоляции сайтов (по умолчанию 1)
        # "dom.ipc.processCount" = 8;               # максимум процессов для вкладок (по умолчанию 8); меньше процессов — меньше памяти
        "browser.tabs.unloadOnLowMemory" = true;  # выгружать фоновые вкладки, когда не хватает ОЗУ
        "browser.startup.page" = 3;               # при запуске восстанавливать вкладки прошлой сессии
        "browser.sessionstore.interval" = 60000;  # раз в минуту сохранять сессию (по умолчанию 15 секунд); меньше записей на диск

        # --- Кэш ---
        "browser.cache.disk.enable" = false;      # не хранить кэш страниц на диске
        "browser.cache.memory.enable" = true;     # хранить его в ОЗУ: быстрее, диск не изнашивается

        # --- Видео ---
        "media.ffmpeg.vaapi.enabled" = true;      # декодировать видео видеокартой, а не процессором (нужен рабочий VA-API)

        # --- Предзагрузка и фоновые запросы ---
        "network.prefetch-next" = false;                   # не загружать заранее страницы по ссылкам «следующая»
        "network.dns.disablePrefetch" = true;              # не резолвить заранее адреса ссылок на странице
        "network.predictor.enabled" = false;               # не предугадывать, какие ресурсы понадобятся
        "browser.urlbar.speculativeConnect.enabled" = false;  # не открывать соединение с сайтом, пока вы ещё набираете адрес
        "browser.search.suggest.enabled" = false;          # не отправлять набираемое поисковику ради подсказок
        "browser.urlbar.suggest.quicksuggest.nonsponsored" = false;  # убрать обычные подсказки Firefox Suggest
        "browser.urlbar.suggest.quicksuggest.sponsored" = false;     # убрать рекламные подсказки в адресной строке

        # --- Новая вкладка ---
        "browser.newtabpage.enabled" = false;                                     # новая вкладка пустая, страница Activity Stream не грузится
        "browser.startup.homepage" = "about:blank";                               # стартовая страница пустая
        "browser.newtabpage.activity-stream.feeds.telemetry" = false;             # телеметрия новой вкладки
        "browser.newtabpage.activity-stream.telemetry" = false;                   # она же, второй переключатель
        "browser.newtabpage.activity-stream.showSponsored" = false;               # не показывать рекламные карточки
        "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;       # не показывать рекламные плитки
        "browser.newtabpage.activity-stream.feeds.section.topstories" = false;    # отключить ленту рекомендаций
        "browser.discovery.enabled" = false;                                      # не персонализировать рекомендации расширений

        # --- ИИ-функции ---
        "browser.ml.enable" = false;                 # отключить локальные ML-модели в браузере
        "browser.ml.chat.enabled" = false;           # убрать боковую панель с чат-ботами
        "browser.tabs.groups.smart.enabled" = false; # отключить «умную» группировку вкладок
        "browser.translations.enable" = false;       # встроенный переводчик, качающий языковые модели (у вас Traduzir)

        # --- Прочий фон ---
        "app.normandy.enabled" = false;                               # отключить удалённое изменение настроек (Normandy)
        "datareporting.healthreport.uploadEnabled" = false;           # не отправлять отчёт о состоянии браузера
        "browser.crashReports.unsubmittedCheck.autoSubmit2" = false;  # не отправлять отчёты о падениях автоматически
        "browser.safebrowsing.downloads.remote.enabled" = false;      # не отправлять Google хеши скачанных файлов; локальная защита остаётся

        "browser.urlbar.suggest.topsites" = false;       # Shortcuts: плитки частых сайтов в подсказках
        "browser.urlbar.suggest.recentsearches" = false; # Recent searches: недавние поисковые запросы
        "browser.urlbar.suggest.engines" = false;        # Suggest search engines: предложения поисковиков
        "browser.urlbar.suggest.quickactions" = false;   # Quick actions: быстрые действия вроде «очистить историю»

        # --- Подсказки адресной строки: только ранее посещённые сайты ---
        "places.history.enabled" = true;                 # хранить историю посещений (источник подсказок)
        "browser.urlbar.suggest.history" = true;         # подсказывать сайты из истории
        "browser.urlbar.suggest.bookmark" = true;        # подсказывать закладки (поставьте false, если нужна только история)
        "browser.urlbar.suggest.openpage" = false;       # не подсказывать уже открытые вкладки
        "browser.urlbar.suggest.searches" = false;       # не подсказывать поисковые запросы
        "browser.urlbar.suggest.trending" = false;       # не показывать популярные запросы
        "browser.urlbar.suggest.weather" = false;        # не показывать погоду
        "browser.urlbar.suggest.addons" = false;         # не подсказывать расширения
        "browser.urlbar.suggest.mdn" = false;            # не подсказывать статьи MDN
        "browser.urlbar.suggest.clipboard" = false;      # не предлагать адрес из буфера обмена

        # --- Тема: Nord ---
        "browser.theme.toolbar-theme" = 0;                                # панели браузера тёмные независимо от системной темы (0 тёмная, 1 светлая, 2 как в системе)
        "browser.theme.content-theme" = 0;                                # меню и внутренние страницы тёмные
        "toolkit.legacyUserProfileCustomizations.stylesheets" = true;     # разрешить userChrome.css / userContent.css
        "layout.css.prefers-color-scheme.content-override" = 0;           # сайты с тёмной темой показывают её (0 тёмная, 1 светлая, 2 как в системе)
      };
    };
  };
}

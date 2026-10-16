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
      };
    };

    profiles.default = {
      isDefault = true;
      settings = {
        # --- Память и процессы ---
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
        "browser.newtabpage.activity-stream.showSponsored" = false;               # не показывать рекламные карточки
        "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;       # не показывать рекламные плитки
        "browser.newtabpage.activity-stream.feeds.section.topstories" = false;    # отключить ленту рекомендаций
        "browser.discovery.enabled" = false;                                      # не персонализировать рекомендации расширений

        # --- ИИ-функции ---
        "browser.ml.enable" = false;                 # отключить локальные ML-модели в браузере
        "browser.ml.chat.enabled" = false;           # убрать боковую панель с чат-ботами
        "browser.tabs.groups.smart.enabled" = false; # отключить «умную» группировку вкладок

        # --- Прочий фон ---
        "app.normandy.enabled" = false;                               # отключить удалённое изменение настроек (Normandy)
        "datareporting.healthreport.uploadEnabled" = false;           # не отправлять отчёт о состоянии браузера
        "browser.crashReports.unsubmittedCheck.autoSubmit2" = false;  # не отправлять отчёты о падениях автоматически
      };
    };
  };
}

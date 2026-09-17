# Игры: Steam и остальное под отдельным пользователем

Статус: модуль `nixos/games.nix` применён на железе, приёмка пройдена (2026-10-27). Открыто — раздел «На железе (позже)».

## Задачи
- Steam-клиент, Proton, non-Steam игры и менеджеры модов. Дальше — Minecraft, WoW, эмуляторы через ту же обёртку.
- Моды правлю из своей сессии, но ничего из библиотеки не запускаю от linqur.
- Steam Link / Remote Play с телефона. Геймпадов нет.
- Удобство как у обычного Steam: трей, ссылки в моём браузере, звук и микрофон.

## Решения
1. **Пользователь `gamesjail` без входа в систему, один на все игры.** Системный, дом `/var/lib/gamesjail` (0700): клиенты, логины, Proton, префиксы.
   - Суффикс `jail` — общий для песочниц: `dockerjail`, `virtjail`, `gamesjail`.
   - Пользователь не привязан ни к Steam, ни к X: от способа вывода зависит только обёртка.
   - Ни демонов, ни linger: всё поднимается командой и завершается вместе с программой.
2. **Обёртка `game <программа>`** от linqur: выдаёт доступы, запускает прокси D-Bus, затем `sudo -u gamesjail` NOPASSWD на один скрипт (аргументы любые — gamesjail слабее linqur, повышения прав нет).
   - `steam` = `game steam`; ярлык Steam в лаунчере ведёт туда же.
   - Свой прокси на каждый запуск: несколько программ работают одновременно.
   - Обёртка не делает exec: держит прокси и убирает его каталог после выхода программы.
3. **Вывод — только X через xwayland-satellite.**
   - niri раздаёт любому обычному Wayland-клиенту screencopy, data-control (буфер обмена), virtual keyboard/pointer, список окон.
   - Клиент Steam всё равно только X (32-бит, CEF), Proton по умолчанию тоже X. HDR не нужен (IPS-панель).
   - Обёртка: `xhost +SI:localuser:gamesjail`; внутри `WAYLAND_DISPLAY` убран, Qt/SDL/GTK принудительно на X.
4. **Звук — ACL на сокет pipewire-pulse.** `u:gamesjail` получает `x` на `/run/user/<uid>` и `pulse/`, `rw` на `pulse/native`; больше ничего из runtime-каталога.
   - `/run/user/<uid>` — tmpfs, пересоздаётся при входе, поэтому `setfacl` на каждый запуск. Цена — миллисекунды до старта, в рантайме ноль.
   - Микрофон работает (pulse даёт и запись).
   - Нативный сокет pipewire не даём: SDL и Proton переходят на pulse.
5. **D-Bus — `xdg-dbus-proxy` к шине linqur с белым списком** (как Flatpak).
   - Трей: `--talk=org.kde.StatusNotifierWatcher`, `--own=org.kde.*` (имена `StatusNotifierItem-<pid>-<n>`, точнее шаблон не позволяет). Вызовы waybar к значку входящие — прокси их не фильтрует.
   - Ссылки: только метод `OpenURI.OpenURI` портала + сигналы `Request`. Внутри `BROWSER` → скрипт с `gdbus call` к порталу; xdg-open в Steam берёт `BROWSER`.
   - Inhibit заставки не нужен: автогашения экрана в системе нет.
   - Всё остальное (systemd --user, секреты, gpg/ssh-агенты) закрыто: через systemd --user был бы побег в сессию linqur.
   - Прокси запускается от linqur, сокет в `$XDG_RUNTIME_DIR/gamesjail.XXXXXX/` с ACL для gamesjail; завершается вместе с обёрткой (`--fd`).
6. **Библиотека — `/srv/games`, ссылка `~/games`.** Группа `gameshare` (linqur, gamesjail), наследуемые ACL rwx, как `/srv/projects`.
   - Клиенты и логины остаются в `/var/lib/gamesjail`.
   - Менеджеры модов и non-Steam игры — в `/srv/games`.
7. **Steam Link / Remote Play:** в фаерволе всегда открыты UDP 27031-27036, TCP 27036-27037. Слушает только запущенный Steam.
8. **`/dev/uinput` не даём.** Виртуальная клавиатура и мышь Steam Input вводили бы в сессию linqur. Без него нет Steam Input и геймпада в Remote Play; схема, как дать безопасно, — в «На железе» (Remote Play).
9. **`hardware.graphics.enable32Bit`** — клиент и большая часть игр 32-битные.
10. **Видеокарта — по программе, не в обёртке.** Клиент Steam на Intel: пока он открыт в трее, dGPU спит.
   - Proton-игры (DXVK/VKD3D) и нативные на Vulkan сами выбирают дискретную карту; нативным на OpenGL — `nvidia-offload %command%` (проверено на Terraria, 2026-10-27).
   - Вне Steam: `game nvidia-offload <программа>`, свои переменные — `game env VAR=… <программа>`, ярлыки так же.
   - Порядок важен: sudo в `game` сбрасывает окружение, `nvidia-offload game …` не сработает. Лишнего процесса нет: export + exec.
11. **MangoHud** — в FHS-окружении Steam (`extraPkgs`): оверлей (FPS, время кадра, загрузка CPU/GPU, какой GPU) и лимит FPS; включается в игре `mangohud %command%`, в фоне не работает.

## Запланировано: вывод через Wayland
Когда Steam и игры перейдут на Wayland — второй режим вывода в обёртке, без изменений пользователя и остального:
- `game --wayland <программа>` и список программ с режимом по умолчанию в конфиге.
- Отдельный Wayland-сокет через `wp_security_context_v1` (niri 26.04 поддерживает): клиент не получает привилегированных протоколов. Сокет живёт, пока работает программа, доступ gamesjail — ACL.
- Утилиты в nixpkgs нет — своя на Rust по образцу `wgamma` (статический musl в `scripts/`): создаёт слушающий сокет в каталоге запуска рядом с прокси D-Bus, регистрирует его через `wp_security_context_v1` (sandbox engine `gamesjail`) и держит, пока жива обёртка.
- niri 26.04 (проверено по исходникам, `client_is_unrestricted`) не даёт таким клиентам: screencopy, wlr/ext data-control, виртуальные клавиатуру и мышь, input method, foreign toplevel, ext-workspace, output management, gamma, layer-shell, session lock, вложенный security context. Обычный буфер (`wl_data_device`) — как у всех, по фокусу. ext-image-copy-capture в niri нет.
- Нужен нативным Wayland-программам вне Steam; клиенту Steam и играм на Proton от Valve — нет.
- Гибрид (Wayland + X) оставляет риски X; полная изоляция — только чистый Wayland.
- Даёт HDR и нативный вывод без Xwayland.

## Отклонено
- **`programs.steam.enable`:** Steam от linqur с доступом ко всему дому, плюс udev-правила uinput.
- **Flatpak Steam:** тот же uid linqur (побег из песочницы → дом), не воспроизводится через Nix.
- **Отдельный пользователь на каждую платформу (Minecraft с модами и т.п.):** пока не нужен; обёртка позволяет добавить позже.
- **Proton-GE:** игры на Proton от Valve. GE — форк с экспериментальными патчами; единственное, что от него было бы нужно, — wine-wayland (`PROTON_ENABLE_WAYLAND=1`), но в нём не работают оверлей и Steam Input. Вернуться, если игра без GE не пойдёт: `proton-ge-bin` через `steam.override { extraEnv.STEAM_EXTRA_COMPAT_TOOLS_PATHS = …; }`, в Steam он называется «GE-Proton» без версии.
- **GameMode:** демон на шине + polkit для смены governor; на ноутбуке с общим бюджетом мощности CPU/GPU пользы почти нет, inhibit не нужен. Важнее профиль питания ASUS (`platform_profile`) — на железе.
- **Пустая шина `dbus-run-session`:** нет трея и ссылок. Запасной вариант, если прокси создаст проблемы.
- **VRR** (2026-10-27): панель `eDP-2` на Intel, niri видит VRR (`supported`) — работал бы и в гибриде, MUX не нужен. Отказались: niri композитит синхронно с экраном, разрывов нет и без VRR; при лимите-делителе 240 кадры ровные, VRR помог бы только на просадках ниже лимита (шаг 4 мс на 240 Гц). Цена — риск мерцания на рабочем столе, а правила niri выбирают окна только по `app-id`/`title` (pid у X-окон — xwayland-satellite), привязка к gamesjail — только переключением `niri msg output eDP-2 vrr on` из обёртки. Вернуться за пять минут, если дёрганье на просадках заметно.

## Принятые риски
- Через X gamesjail видит X-окна linqur (только X-клиенты, Wayland-окна — нет) и буфер обмена при его изменении.
- Пока программа запущена, ей доступен микрофон.
- Трей Wine-программ (Battle.net): Wine умеет только XEmbed, waybar — только SNI, поэтому Wine показывает свой трей отдельным окном. Скрыть — `ShowSystray=0` в `HKCU\Software\Wine\Explorer` префикса (тогда закрытие окна должно завершать программу); мост `xembedsniproxy` тянет Plasma. Оставлено как есть.
- Вход через Google в Battle.net не возвращается в клиент (браузер linqur не передаёт ответ в программу под Wine); входить по логину и паролю.
- Игры между собой не изолированы: вредоносный мод может прочитать логины Steam и других лаунчеров (не дом linqur).
- Через OpenURI программа может попросить открыть файл или ссылку в приложениях linqur.
- Права на правку `/srv/games` у linqur — запуск оттуда от linqur запрещён только договорённостью.

Бэкап `/var/lib/gamesjail` не делаем: сохранения в Steam Cloud, остальное переносится руками.

## Как пользоваться
- `steam` из терминала или лаунчера; другие программы — `game <программа>`.
- Настройки клиента — раздел ниже.
- Игры и моды — `~/games` (= `/srv/games`); у gamesjail та же ссылка `/var/lib/gamesjail/games` — диалог выбора файлов GTK под `game` открывается в его доме (свой пикер gamesjail, не Thunar linqur).
- MangoHud: в параметрах запуска игры `mangohud %command%`; лимит FPS для Proton (DirectX 9–11) — `DXVK_FRAME_RATE=120 %command%`. Лимит — делитель 240 (120, 80, 60), который игра стабильно держит: каждый кадр показывается ровно N обновлений экрана.

## Настройки клиента Steam (2026-10-27)
Steam хранит их в своих vdf и перезаписывает сам — задаются руками, список здесь.
- Compatibility: «Enable Steam Play for all other titles», Proton Experimental — иначе непроверенные Windows-игры не ставятся.
- Storage: `/srv/games` — библиотека по умолчанию (сделано).
- Downloads → Shader Pre-Caching: pre-caching включён, «Allow background processing of Vulkan shaders» выключен — шейдеры обрабатываются перед запуском игры (можно пропустить), в трее Steam ничего не компилирует.
  - Кэш шейдеров на игру — `steamapps/shadercache/<appid>` (DXVK, NVIDIA, Mesa), переживает перезапуски; сбрасывается обновлением драйвера NVIDIA, Proton/DXVK или игры.
  - Если игра компилирует шейдеры на своём экране загрузки при каждом запуске (Unity и т.п.) — это сама игра, Steam не влияет.
- Downloads: «Allow downloads during gameplay» выключено; нужно — запускаю загрузку из библиотеки вручную.
- In Game: оверлей включён, счётчик FPS Steam выключен (MangoHud). Оверлей стоит ~0–2% FPS (по памяти, не мерили); без него нет Shift+Tab, F12, покупок в играх, части приглашений, Remote Play Together. Если игра с ним дёргается или падает — выключить в свойствах этой игры.
- Interface: автозапуск выключен, ускорение веб-интерфейса включено (клиент на Intel).
- Cloud: включён — это бэкап сохранений.

## Миграция песочницы VM после переименования
`mutableUsers = true`: userborn не переименует существующих пользователей, uid займут старые записи. До switch:
- `dockdev` → `dockerjail` (uid 1001, дом `/home/dockdev` → `/home/dockerjail`, linger).
- `virtdev` → `virtjail` (дом `/var/lib/virtdev` → `/var/lib/virtjail`); в XML VM пути `/etc/profiles/per-user/virtdev` и `/var/lib/virtdev` → `virtjail`.

## Приёмка в VM
- [x] после переименования: `docker ps`, virt-manager открывает VM (2026-10-27)
- [x] `steam` запускается, процессы клиента от `gamesjail`, `/home/linqur` из него не читается
- [x] после выхода из Steam не остаётся процессов `gamesjail`, прокси и каталога `gamesjail.*` в `/run/user/<uid>` (2026-10-27; ACL на `/run/user/<uid>` и `pulse/` остаются до перелогина — так задумано)
- [x] повторный `steam` при запущенном клиенте: Steam из трея открывается на активном рабочем столе с фокусом, второй прокси и каталог `gamesjail.*` убираются сразу (2026-10-27)
- [x] два запуска одновременно (`steam` и `game <что-то>`) — у каждого свой прокси (2026-10-27: `steam` + `game sleep 120` — два прокси и два каталога; после выхода `sleep` остались только у Steam)
- [x] логин, скачивание игры в библиотеку `/srv/games` (2026-10-27)
- [x] лёгкая игра запускается (программный рендеринг), Proton-игра стартует: Bloody Trapland идёт через Proton Experimental (2026-10-27)
- [x] MangoHud показывается в игре (2026-10-27, Bloody Trapland)
- [x] `nvidia-offload` виден внутри FHS Steam (иначе — в `extraPkgs`): игра стартует с `nvidia-offload mangohud %command%` (2026-10-27)
- [x] на железе: с открытым Steam dGPU спит (`/sys/bus/pci/devices/<dGPU>/power/runtime_status` = suspended); Proton-игра без параметров идёт на NVIDIA, нативная — с `nvidia-offload %command%`. 2026-10-27: клиент Steam (`steam`, `steamwebhelper`) держит только Intel `renderD129`; Bloody Trapland с `nvidia-offload` держит `/dev/nvidia0`, переменные PRIME дошли до `.exe`. После выхода из игры при открытом Steam dGPU сразу `suspended`, процессов Wine не осталось. Proton-игра без параметров тоже на NVIDIA: DXVK сам выбирает дискретную (`/dev/nvidia0` и `libnvidia-glvkspirv` в процессе, переменных PRIME нет), `nvidia-offload` для Proton не нужен. Нативная Terraria (FNA3D/SDL3) без параметров тоже на NVIDIA — похоже, через Vulkan (в процессе Vulkan-драйвер NVIDIA, Xwayland на Intel). `nvidia-offload` нужен только нативным OpenGL-играм. Terraria с `nvidia-offload %command%` — переменные PRIME в процессе, OpenGL-драйвер NVIDIA (`libGLX_nvidia`), на NVIDIA. С `FNA3D_FORCE_DRIVER=OpenGL %command%` без offload — Intel (`renderD129`, Mesa), dGPU `suspended`
- [x] звук в игре, микрофон в настройках голоса Steam (2026-10-27: Bloody Trapland под Proton — звук чистый; микрофон в тесте Steam слышен, качество портит обработка голоса Steam: запись `pw-record` от linqur чистая, Discord звучит иначе — песочница ни при чём, 2026-10-27)
- [x] значок Steam в трее waybar, меню работает (2026-10-27)
- [x] ссылка из Steam открывается в браузере linqur: внешние ссылки клиента (`steam://openurl_external/...`) и прямой вызов портала открываются. Ссылки внутри страниц магазина и сообщества (кнопки в новостях, «Watch on YouTube») Steam открывает во встроенном браузере и наружу не передаёт — так устроен клиент, не песочница; адрес копирую вручную. Портал оставлен для остальных программ под `game`
- [x] из шины gamesjail недоступны `org.freedesktop.systemd1` и секреты
- [x] non-Steam игра из `/srv/games` добавляется и запускается (2026-10-27: Battle.net — установщик из `/srv/games`, Proton Experimental, всё от gamesjail; префикс non-Steam записей Steam создаёт в `/var/lib/gamesjail/.../compatdata/<id>`; ссылка входа открылась в браузере linqur через портал, вход по логину и паролю)
- [x] linqur правит файлы в `~/games`, ACL наследуются на новые файлы
- [x] порты Steam Link открыты (`nft list ruleset`)
- [x] после switch с фиксом: игра, запущенная после старта Steam, получает звук (pipewire-pulse поднимается до ACL). 2026-10-21: Proton-игра 257750 упала с `NoAudioHardwareException`. 2026-10-27: та же игра запущена после Steam — потоки `wine-preloader` от gamesjail в PipeWire, звук есть
- [x] перелогин linqur → `steam` снова получает звук (ACL выдаётся заново). 2026-10-27: после перезагрузки доступы выданы заново, звук есть

## На железе (позже)
- Ссылки из GTK-программ (`gio open`): `GIO_USE_PORTALS=1` в `jailExec` (2026-10-27) — GIO идёт в портал OpenURI, как во Flatpak. Без неё `gio open` → `Operation not supported`, с ней ссылка открылась в браузере linqur; диалог выбора файлов GTK (zenity) открывается и с ней — портал FileChooser прокси не пропускает, GTK показывает свой. Проверить после switch: `game gio open https://example.org`.
- **Remote Play отложен (2026-10-27).** Подключение с телефона работает, картинка игры идёт (захват через оверлей, `Game Vulkan`). Что не работает:
  - Клиент Steam на телефоне не виден: захват PipeWire (способ Steam Deck, ждёт поток от gamescope) падает — у gamesjail нет PipeWire, и давать его не будем (запись всех потоков и микрофона); запасной захват корневого окна X пустой — у xwayland-satellite корень пустой. Портал ScreenCast Steam в X-сеансе не пробует. Решения — свой X-сервер (rootful Xwayland или gamescope) — отклонены: Steam и игры жили бы в одном окне. Ждём нативный Wayland в Steam; до тех пор игру запускать на ноутбуке, потом подключаться.
  - Управление: сенсорный геймпад телефона — виртуальный геймпад через `/dev/uinput` (`Couldn't open /dev/uinput for writing`). Тот же uinput нужен Steam Input для живых контроллеров. Найденная схема: ACL на `/dev/uinput` только gamesjail; udev для `/devices/virtual/input/*` — `LIBINPUT_IGNORE_DEVICE=1`, снять `power-switch`, читать только gamesjail, запись в журнал (`virtual-input`); проверка при сборке на `hardware.uinput.enable`. Создателя uinput-устройства ядро не хранит, имя подделывается — отличить устройства gamesjail от своих (keyd, ydotool, Sunshine) нельзя, при появлении такой программы выбирать. uhid (Bluetooth LE) лежит в `/devices/virtual/misc/uhid`, правило не задевает. Пространства имён не помогают — подсистема ввода общая. libei — только клавиатура и мышь, для геймпадов стандарта нет.
- Живые контроллеры (USB, Bluetooth): пока нет, вернусь сам. Без Steam Input — только доступ gamesjail к их `event`/`hidraw`, uinput не нужен; со Steam Input — схема uinput выше.

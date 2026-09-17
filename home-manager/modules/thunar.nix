# Действия Thunar по правому клику: архивы через ouch, без плагина и GUI-архиватора.
# Команда идёт в окне foot: видно ход работы, вопросы ouch (перезапись, пароль) и ошибки.
# Файл — ссылка в store: правка действий через меню Thunar не сохранится, только здесь
let
  # окно закрывается само при успехе; при ошибке ждёт Enter, чтобы её можно было прочитать
  inFoot = cmd: ''foot -D %d sh -c '${cmd} || { echo; read -p "Ошибка. Enter — закрыть" _; }' _'';
  archives = "*.zip;*.7z;*.rar;*.tar;*.tar.*;*.tgz;*.tbz2;*.txz;*.tzst;*.gz;*.xz;*.zst;*.bz2;*.bz3;*.lz4;*.lz;*.lzma;*.br;*.sz";
in
{
  # Настройки Thunar (xfconf, канал thunar) ставятся при каждом switch; правка мышкой живёт до следующего.
  # Размеры окна, ширины колонок и сортировка — состояние, не задаём
  xfconf.settings.thunar = {
    "last-view" = "ThunarDetailsView"; # список
    "last-location-bar" = "ThunarLocationEntry"; # адрес текстом
    "last-side-pane" = "THUNAR_SIDEPANE_TYPE_TREE";
    "last-statusbar-visible" = false;
    "last-menubar-visible" = false; # меню — кнопкой-бургером на панели
    # на панели только бургер и адрес; действия uca Thunar дописывает сам
    "last-toolbar-items" = "menu:1,back:0,forward:0,open-parent:0,open-home:0,new-tab:0,new-window:0,toggle-split-view:0,undo:0,redo:0,zoom-out:0,zoom-in:0,zoom-reset:0,view-as-icons:0,view-as-detailed-list:0,view-as-compact-list:0,view-switcher:0,location-bar:1,reload:0,search:0";
    "last-show-hidden" = true;
    "misc-always-enable-split-view" = false;
    # крупный просмотр выделенной картинки отдельной колонкой справа (Вид → Боковая панель → Image Preview);
    # картинку даёт tumbler, как и миниатюры
    "misc-image-preview-mode" = "THUNAR_IMAGE_PREVIEW_MODE_STANDALONE";
    "misc-date-style" = "THUNAR_DATE_STYLE_ISO"; # 2026-10-26 16:40
    "misc-folder-item-count" = "THUNAR_FOLDER_ITEM_COUNT_ONLY_LOCAL"; # у папок в колонке «Размер» — число элементов
    "misc-middle-click-in-tab" = true; # колёсико открывает папку во вкладке
    "misc-window-title-style" = "THUNAR_WINDOW_TITLE_STYLE_FULL_PATH_WITHOUT_THUNAR_SUFFIX";
  };

  # Del удаляет сразу навсегда (с подтверждением), корзину не используем.
  # Без gvfs схемы trash:// нет, и Thunar так делает сам; здесь — явно, чтобы не зависеть от gvfs.
  # Остальные клавиши Thunar берёт по умолчанию; файл в store, свои правки клавиш он не сохранит
  xdg.configFile."Thunar/accels.scm".text = ''
    (gtk_accel_path "<Actions>/ThunarActionManager/trash-delete" "")
    (gtk_accel_path "<Actions>/ThunarActionManager/trash-delete-2" "")
    (gtk_accel_path "<Actions>/ThunarActionManager/delete" "Delete")
    (gtk_accel_path "<Actions>/ThunarActionManager/delete-3" "KP_Delete")
  '';

  xdg.configFile."Thunar/uca.xml".text = ''
    <?xml version="1.0" encoding="UTF-8"?>
    <actions>
      <action>
        <icon>package-x-generic</icon>
        <name>Распаковать</name>
        <unique-id>ouch-decompress</unique-id>
        <command>${inFoot ''ouch d "$@"''} %F</command>
        <description>ouch: каждый архив в папку по его имени</description>
        <patterns>${archives}</patterns>
        <other-files/>
      </action>
      <action>
        <icon>package-x-generic</icon>
        <name>Упаковать в zip</name>
        <unique-id>ouch-compress-zip</unique-id>
        <command>${inFoot ''ouch c "$@" "$(basename "$1").zip"''} %N</command>
        <description>ouch: выбранное в &lt;первый&gt;.zip рядом</description>
        <patterns>*</patterns>
        <directories/><other-files/><text-files/><image-files/><audio-files/><video-files/>
      </action>
    </actions>
  '';
}

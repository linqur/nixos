# Корзины нет: на месте ~/.local/share/Trash — файл из store (только чтение).
# GIO, Qt и Electron создают каталог корзины при первом «в корзину»; файл на этом месте не даёт его создать,
# перенос падает с ошибкой («Unable to create trash directory … Not a directory»), а файл остаётся на месте.
# Удаление — только навсегда; Thunar и VS Code настроены удалять сразу (thunar.nix, vscode.nix)
{
  xdg.dataFile."Trash".text = ''
    Корзина отключена: home-manager/modules/no-trash.nix
  '';
}

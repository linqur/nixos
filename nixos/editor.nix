{ pkgs, ... }:

{
  # helix — редактор по умолчанию для всей системы, включая root и sudoedit
  # (у пользователя EDITOR задаёт ещё и home-manager/modules/helix.nix)
  environment.systemPackages = [ pkgs.helix ];
  environment.variables = {
    EDITOR = "hx";  # перекрывает mkDefault "nano" из programs/environment.nix
    VISUAL = "hx";
  };
}

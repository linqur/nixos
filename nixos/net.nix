{
  networking.networkmanager.enable = true;

  # Фаервол одним `nft -f` вместо десятков вызовов iptables; набор правил проверяется при сборке
  networking.nftables.enable = true;
}

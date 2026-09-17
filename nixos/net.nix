{
  networking.networkmanager.enable = true;

  # Фаервол одним `nft -f` вместо десятков вызовов iptables; набор правил проверяется при сборке
  networking.nftables.enable = true;

  # Не писать каждый отброшенный пакет в журнал: лишние записи на диск и работа CPU
  networking.firewall.logRefusedConnections = false;

  # BBR + fq: стабильность соединений при потерях и задержках
  boot.kernel.sysctl = {
    "net.core.default_qdisc" = "fq";
    "net.ipv4.tcp_congestion_control" = "bbr";
  };
}

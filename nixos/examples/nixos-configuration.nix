# Пример конфигурации NixOS с кастомным модулем zapret
{ config, pkgs, inputs, ... }:

{
  # Импортируем zapret модуль из flake
  imports = [
    inputs.zapret-discord-youtube.nixosModules.default
  ];

  # Настройка zapret с выбором конфигурации
  services.zapret-discord-youtube = {
    enable = true;
    
    # Выбираем конфигурацию (любую из папки configs/)
    config = "general"; # или "general(ALT)", "general(МГТС)", "general_(FAKE_TLS)", etc.
    
    # Тип фаерволла
    firewallType = "iptables"; # или "nftables"
    
    # Включить IPv6 поддержку (по умолчанию отключено)
    enableIPv6 = false;
    
    # Путь к конфигурациям (по умолчанию ./configs)
    # configPath = /path/to/custom/configs;
    
    # Дополнительные hostlists (опционально)
    customHostlists = [
      # /path/to/custom/hostlist.txt
    ];
  };

  # Разрешаем IP форвардинг для работы zapret
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };

  # Настройки сети (пример)
  networking = {
    hostName = "nixos-zapret";
    firewall.enable = true; # zapret управляет своими правилами автоматически
  };

  # Остальные настройки системы...
  system.stateVersion = "25.05";
}

# ===== ИСПОЛЬЗОВАНИЕ В flake.nix =====
# {
#   inputs = {
#     nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
#     zapret.url = "github:user/zapret-nixos-flake";
#   };
#
#   outputs = { self, nixpkgs, zapret }: {
#     nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
#       system = "x86_64-linux";
#       specialArgs = { inherit inputs; };
#       modules = [
#         ./configuration.nix
#         zapret.nixosModules.default
#       ];
#     };
#   };
# } 
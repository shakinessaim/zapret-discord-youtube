# Пример использования zapret flake в NixOS configuration
{ config, pkgs, inputs, ... }:

{
  # Импортируем zapret модуль из flake
  imports = [
    inputs.zapret.nixosModules.default
  ];

  # Настройка zapret
  services.zapret = {
    enable = true;
    
    # Выбираем конфигурацию (по умолчанию "general")
    config = "general"; # или любой из: general_ALT, general_ALT2, etc.
    
    # Тип фаерволла
    firewallType = "iptables"; # или "nftables"
    
    # Включить IPv6 поддержку
    enableIPv6 = false;
    
    # Дополнительные hostlists (опционально)
    customHostlists = [
      # "/path/to/custom/hostlist.txt"
    ];
  };

  # Дополнительные настройки сети (если нужны)
  networking = {
    firewall = {
      enable = true;
      # Разрешить zapret управлять правилами
      extraCommands = ''
        # Zapret будет автоматически добавлять свои правила
      '';
    };
  };

  # Включаем необходимые службы
  services.resolved.enable = true;
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
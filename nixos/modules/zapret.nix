{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.zapret;
  
  # Определяем доступные конфигурации
  availableConfigs = {
    general = "general";
    general_ALT = "general(ALT)";
    general_ALT2 = "general(ALT2)";
    general_ALT3 = "general(ALT3)";
    general_ALT4 = "general(ALT4)";
    general_ALT5 = "general(ALT5)";
    general_ALT6 = "general(ALT6)";
    general_MGTS = "general(МГТС)";
    general_MGTS2 = "general(МГТС2)";
    general_FAKE_TLS = "general_(FAKE_TLS)";
    general_FAKE_TLS_AUTO = "general_(FAKE_TLS_AUTO)";
    general_FAKE_TLS_AUTO_ALT = "general_(FAKE_TLS_AUTO_ALT)";
    general_FAKE_TLS_AUTO_ALT2 = "general_(FAKE_TLS_AUTO_ALT2)";
    general_FAKE_TLS_ALT = "general_(FAKE_TLS_ALT)";
  };

  zapretPackage = pkgs.callPackage ../packages/zapret.nix { };
  
  # Функция для создания конфигурационного файла с заменой путей
  makeConfig = configName: let
    originalConfig = builtins.readFile ../../configs/${availableConfigs.${configName}};
    # Заменяем хардкод пути на Nix store пути
    patchedConfig = builtins.replaceStrings
      [ "/opt/zapret/hostlists/" "/opt/zapret/files/" ]
      [ "/etc/zapret/hostlists/" "${zapretPackage}/share/zapret/files/" ]
      originalConfig;
  in pkgs.writeText "zapret-config" patchedConfig;
  
  # Hostlists
  hostlistsPath = pkgs.runCommand "zapret-hostlists" {} ''
    mkdir -p $out
    cp -r ${../../hostlists}/* $out/
  '';

in {
  options.services.zapret = {
    enable = mkEnableOption "Zapret DPI bypass service";

    config = mkOption {
      type = types.enum (attrNames availableConfigs);
      default = "general";
      description = ''
        Zapret configuration to use. Available options:
        ${concatStringsSep "\n        " (mapAttrsToList (name: desc: "- ${name}: ${desc}") availableConfigs)}
      '';
    };

    customHostlists = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Additional hostlists to include";
    };

    firewallType = mkOption {
      type = types.enum [ "iptables" "nftables" ];
      default = "iptables";
      description = "Firewall type to use";
    };

    enableIPv6 = mkOption {
      type = types.bool;
      default = false;
      description = "Enable IPv6 support";
    };
  };

  config = mkIf cfg.enable {
    # Установка пакета
    environment.systemPackages = [ zapretPackage ];

    # Создание директорий и файлов
    environment.etc = {
      "zapret/config".source = makeConfig cfg.config;
      "zapret/hostlists".source = hostlistsPath;
    };

    # Включаем необходимые модули ядра
    boot.kernelModules = [ "xt_NFQUEUE" "xt_connbytes" "xt_mark" "xt_set" ];
    
    # Системные пакеты
    environment.systemPackages = with pkgs; [
      iptables
      ipset
      (if cfg.firewallType == "nftables" then nftables else iptables)
    ];

    # systemd service
    systemd.services.zapret = {
      description = "Zapret DPI bypass service";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "forking";
        RemainAfterExit = true;
        ExecStart = "${pkgs.bash}/bin/bash -c 'cd /var/lib/zapret && source config && ${zapretPackage}/share/zapret/init.d/systemd/zapret-service start'";
        ExecStop = "${pkgs.bash}/bin/bash -c 'cd /var/lib/zapret && source config && ${zapretPackage}/share/zapret/init.d/systemd/zapret-service stop'";
        ExecReload = "${pkgs.bash}/bin/bash -c 'cd /var/lib/zapret && source config && ${zapretPackage}/share/zapret/init.d/systemd/zapret-service restart'";
        
        # Security настройки
        NoNewPrivileges = false; # zapret нужны привилегии для работы с netfilter
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        
        # Рабочая директория
        WorkingDirectory = "/var/lib/zapret";
        
        # Переменные окружения
        Environment = [
          "ZAPRET_CONFIG=/var/lib/zapret/config"
          "ZAPRET_BASE=${zapretPackage}/share/zapret"
          "FWTYPE=${cfg.firewallType}"
        ] ++ optional (!cfg.enableIPv6) "DISABLE_IPV6=1";
      };
      
      preStart = ''
        # Создаем рабочую директорию
        mkdir -p /var/lib/zapret
        
        # Копируем конфиг и hostlists в рабочую директорию
        cp /etc/zapret/config /var/lib/zapret/config
        mkdir -p /var/lib/zapret/hostlists
        cp -r /etc/zapret/hostlists/* /var/lib/zapret/hostlists/ || true
      '';
    };

    # Сетевые настройки
    boot.kernel.sysctl = mkIf cfg.enableIPv6 {
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
    };

    # Firewall rules
    networking.firewall.enable = mkDefault true;
    networking.firewall.allowedTCPPorts = mkDefault [];
    networking.firewall.allowedUDPPorts = mkDefault [];
  };
} 
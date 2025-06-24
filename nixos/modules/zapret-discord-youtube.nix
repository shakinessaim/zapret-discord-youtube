{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.zapret-discord-youtube;
  
  zapretPkg = pkgs.callPackage ../packages/zapret-discord-youtube.nix { };
  
  configFile = "${cfg.configPath}/${cfg.config}";
  
  # Добавляем gnused для замены путей в конфигурации
  runtimeDeps = with pkgs; [ gnused kmod ];
    
  firewallScript = pkgs.writeShellScript "zapret-firewall" ''
    set -e
    
    # Базовый путь к zapret
    ZAPRET_BASE="${zapretPkg}/opt/zapret"
    
    # Проверка существования конфигурации
    if [ ! -f "${configFile}" ]; then
      echo "Error: Configuration file ${configFile} not found!"
      exit 1
    fi
    
    # Создаем временную копию конфигурации где ожидает zapret
    mkdir -p /tmp/zapret-config
    
    # Заменяем hardcoded пути /opt/zapret/ на правильные Nix store пути
    ${pkgs.gnused}/bin/sed 's|/opt/zapret/|${zapretPkg}/opt/zapret/|g' "${configFile}" > /tmp/zapret-config/config
    
    # Загружаем конфигурацию
    source /tmp/zapret-config/config
    
    # Экспортируем необходимые переменные
    export ZAPRET_BASE
    export TPPORT_SOCKS
    export NFQWS_PORTS_TCP
    export NFQWS_PORTS_UDP
    export NFQWS_TCP_PKT_OUT
    export NFQWS_TCP_PKT_IN
    export NFQWS_UDP_PKT_OUT
    export NFQWS_UDP_PKT_IN
    export DESYNC_MARK
    export DESYNC_MARK_POSTNAT
    export FWTYPE
    
    # Создаем симлинк на конфигурацию в нужное место
    ln -sf /tmp/zapret-config/config ${zapretPkg}/opt/zapret/config
    
    # Создаем и применяем правила фаерволла
    case "$1" in
      start)
        echo "Starting zapret firewall rules..."
        ${zapretPkg}/opt/zapret/init.d/sysv/zapret start
        ;;
      stop)
        echo "Stopping zapret firewall rules..."
        ${zapretPkg}/opt/zapret/init.d/sysv/zapret stop
        ;;
      *)
        echo "Usage: $0 {start|stop}"
        exit 1
        ;;
    esac
  '';

in {
  options.services.zapret-discord-youtube = {
    enable = mkEnableOption "Zapret DPI bypass tool for Discord and YouTube";
    
    config = mkOption {
      type = types.str;
      default = "general";
      description = "Configuration name from configs directory (e.g., 'general', 'general(ALT)', 'general(МГТС)')";
    };
    
    configPath = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to directory containing zapret configuration files. Must be set explicitly.";
      example = "/path/to/your/configs";
    };
    
    firewallType = mkOption {
      type = types.enum [ "iptables" "nftables" ];
      default = "iptables";
      description = "Type of firewall to use";
    };
    
    enableIPv6 = mkOption {
      type = types.bool;
      default = false;
      description = "Enable IPv6 support";
    };
    
    customHostlists = mkOption {
      type = types.listOf types.path;
      default = [];
      description = "Additional hostlist files to include";
    };
  };

  config = mkIf cfg.enable {
    # Устанавливаем пакет zapret
    environment.systemPackages = [ zapretPkg ];
    
    # Проверяем наличие конфигурационного файла
    assertions = [
      {
        assertion = cfg.configPath != null;
        message = "services.zapret-discord-youtube.configPath must be set explicitly. Example: configPath = ./configs;";
      }
      {
        assertion = cfg.configPath != null -> builtins.pathExists configFile;
        message = "Zapret configuration file ${cfg.config} not found in ${toString cfg.configPath}";
      }
    ];
    
    # Создаем systemd сервис для управления zapret
    systemd.services.zapret-discord-youtube = {
      description = "Zapret DPI bypass for Discord and YouTube";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "forking";
        ExecStart = "${firewallScript} start";
        ExecStop = "${firewallScript} stop";
        RemainAfterExit = true;
        TimeoutSec = 30;
      };
      
      preStart = ''
        # Проверяем доступность необходимых модулей ядра
        ${lib.getExe' pkgs.kmod "modprobe"} xt_NFQUEUE || true
        ${lib.getExe' pkgs.kmod "modprobe"} xt_connbytes || true
        ${lib.getExe' pkgs.kmod "modprobe"} xt_mark || true
        ${lib.getExe' pkgs.kmod "modprobe"} xt_tcpudp || true
      '';
    };
    
    # Настройки ядра для корректной работы zapret
    boot.kernel.sysctl = {
      "net.netfilter.nf_conntrack_tcp_be_liberal" = 1;
      "net.netfilter.nf_conntrack_tcp_loose" = 1;
    } // optionalAttrs (!cfg.enableIPv6) {
      "net.ipv6.conf.all.disable_ipv6" = 1;
      "net.ipv6.conf.default.disable_ipv6" = 1;
    };
    
    # Загружаем необходимые модули ядра
    boot.kernelModules = [
      "xt_NFQUEUE"
      "xt_connbytes" 
      "xt_mark"
      "xt_tcpudp"
      "nfnetlink_queue"
    ];
    
    # Включаем IP forwarding если это роутер
    networking.firewall.enable = lib.mkDefault true;
  };
} 
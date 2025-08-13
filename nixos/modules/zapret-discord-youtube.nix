{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.zapret-discord-youtube;
  zapretPackage = pkgs.callPackage ../packages/zapret-discord-youtube.nix {
    configName = cfg.config;
  };
in {
  options.services.zapret-discord-youtube = {
    enable = mkEnableOption "zapret DPI bypass for Discord and YouTube";
    
    config = mkOption {
      type = types.str;
      default = "general";
      description = "Configuration name to use from configs directory";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ zapretPackage ];
    
    # Создаем пользователя tpws, которого ожидает zapret
    users.users.tpws = {
      isSystemUser = true;
      group = "tpws";
    };
    
    users.groups.tpws = {};
    
        # Используем готовый systemd файл от zapret
    systemd.services.zapret-discord-youtube = {
      description = "Zapret DPI bypass for Discord and YouTube";
      after = [ "network-online.target" "firewall.service" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      
      preStart = ''
        # Предварительно очищаем правила zapret
        ${zapretPackage}/opt/zapret/init.d/sysv/zapret stop || true
        
        # Создаем необходимые ipset если их нет
        if ! ipset list nozapret >/dev/null 2>&1; then
          ipset create nozapret hash:net
        fi
        
        # Проверяем доступность модулей ядра
        modprobe xt_NFQUEUE 2>/dev/null || true
        modprobe xt_connbytes 2>/dev/null || true
        modprobe xt_multiport 2>/dev/null || true
      '';
      
      serviceConfig = {
        Type = "forking";
        ExecStart = "${zapretPackage}/opt/zapret/init.d/sysv/zapret start";
        ExecStop = "${zapretPackage}/opt/zapret/init.d/sysv/zapret stop";
        Restart = "no";
        TimeoutSec = 30;
        IgnoreSIGPIPE = false;
        KillMode = "none";
        GuessMainPID = false;
        RemainAfterExit = false;
        
        # Добавляем переменные окружения и PATH
        Environment = [
          "ZAPRET_BASE=${zapretPackage}/opt/zapret"
          "PATH=${lib.makeBinPath (with pkgs; [ iptables ipset coreutils gawk curl wget bash kmod ])}:/run/current-system/sw/bin"
        ];
        
        # Запускаем от root для управления сетью
        User = "root";
        Group = "root";
    
        # Расширенные возможности для работы с сетью и модулями
        AmbientCapabilities = [ "CAP_NET_ADMIN" "CAP_NET_RAW" "CAP_SETGID" "CAP_SYS_MODULE" ];
        CapabilityBoundingSet = [ "CAP_NET_ADMIN" "CAP_NET_RAW" "CAP_SETGID" "CAP_SYS_MODULE" ];
        
        # Разрешаем доступ к /sys для модулей
        PrivateDevices = false;
        ProtectKernelModules = false;
      };
    };
    
    # Оставляем firewall включенным, но разрешаем zapret работать с mangle таблицей
    networking.firewall = {
      # Zapret работает с mangle таблицей, не конфликтует с filter таблицей firewall
      extraCommands = ''
        # Создаем ipset для zapret если его нет
        if ! ipset list nozapret >/dev/null 2>&1; then
          ipset create nozapret hash:net
        fi
        
        # Проверяем доступность модулей ядра
        modprobe xt_NFQUEUE 2>/dev/null || true
        modprobe xt_connbytes 2>/dev/null || true
        modprobe xt_multiport 2>/dev/null || true
      '';
    };
    
    # Добавляем необходимые модули ядра
    boot.kernelModules = [ "xt_NFQUEUE" "xt_connbytes" "xt_multiport" ];
  };
} 
{ lib
, stdenv
, fetchurl
, fetchFromGitHub
, makeWrapper
, iptables
, ipset
, coreutils
, bash
, gawk
, curl
, wget
, configName ? "general"
}:

stdenv.mkDerivation rec {
  pname = "zapret";
  version = "71.3";

  src = fetchurl {
    url = "https://github.com/bol-van/zapret/releases/download/v${version}/zapret-v${version}.tar.gz";
    hash = "sha256-LeDotLFH8Rml4kiXebig1jGUROWDst18HU1bC8+4djU=";
  };

  # Загружаем конфигурации заранее
  configsSrc = fetchFromGitHub {
    owner = "kartavkun";
    repo = "zapret-discord-youtube";
    rev = "main";
    hash = "sha256-T1bh7zZOaEQtd4d0JqqfJoMhyfkVKDbTiqhKOuz6MgQ=";
  };

  nativeBuildInputs = [ makeWrapper ];

  buildInputs = [
    iptables
    ipset
    coreutils
    bash
    gawk
    curl
    wget
  ];

  # Не нужно собирать - бинарники уже готовые
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    
    mkdir -p $out/bin
    mkdir -p $out/opt/zapret
    
    # Создаем временную папку для обработки
    mkdir -p /tmp/zapret-build
    
    # Копируем все файлы zapret во временную папку
    cp -r * /tmp/zapret-build/
    
    # Копируем hostlists из configsSrc
    echo "Копирование hostlists..."
    mkdir -p /tmp/zapret-build/hostlists
    cp -v $configsSrc/hostlists/* /tmp/zapret-build/hostlists/
    echo "Проверка скопированных файлов:"
    ls -la /tmp/zapret-build/hostlists/
    
    # Копируем configs из configsSrc
    echo "Копирование папки configs..."
    mkdir -p /tmp/zapret-build/configs
    cp -r $configsSrc/configs/* /tmp/zapret-build/configs/
    
    # Обрабатываем все файлы во временной папке
    echo "Обработка конфигурационных файлов..."
    
    # Заменяем все пути /opt/zapret на правильные Nix store пути
    find /tmp/zapret-build -type f -exec sed -i 's|/opt/zapret|'$out'/opt/zapret|g' {} \;
    
    # Изменяем MODE_FILTER с none на hostlist для корректной работы
    find /tmp/zapret-build/configs -type f -exec sed -i 's|MODE_FILTER=none|MODE_FILTER=hostlist|g' {} \;
    
    # Раскомментируем и заменяем WS_USER на root в конфигурационных файлах
    echo "Переопределение пользователя WS_USER на root..."
    find /tmp/zapret-build/configs -type f -exec sed -i 's|^#WS_USER=.*|WS_USER=root|g' {} \;
    find /tmp/zapret-build/configs -type f -exec sed -i 's|^WS_USER=.*|WS_USER=root|g' {} \;
    
    # Также добавляем WS_USER=root в начало каждого конфигурационного файла если его там нет
    for config_file in /tmp/zapret-build/configs/*; do
      if [ -f "$config_file" ]; then
        # Проверяем есть ли уже WS_USER в файле
        if ! grep -q "WS_USER=" "$config_file"; then
          # Добавляем WS_USER=root в начало файла после комментариев
          sed -i '1a\\n# Override user for zapret daemons\nWS_USER=root\n' "$config_file"
        fi
      fi
    done
    
    # Заменяем hardcoded пользователь tpws на root в скриптах
    echo "Замена hardcoded пользователя tpws на root..."
    find /tmp/zapret-build -type f \( -name "*.sh" -o -name "zapret" -o -name "functions" \) -exec sed -i 's/--user=tpws/--user=root/g' {} \;
    
    # Патчим скрипты для использования правильных путей к утилитам
    echo "Патчинг скриптов для NixOS..."
    
    # Заменяем пути к утилитам во всех скриптах
    find /tmp/zapret-build -name "*.sh" -exec sed -i \
      -e 's|^iptables |${iptables}/bin/iptables |g' \
      -e 's|command -v iptables|command -v ${iptables}/bin/iptables|g' \
      -e 's|\<iptables\>|${iptables}/bin/iptables|g' \
      -e 's|^ip6tables |${iptables}/bin/ip6tables |g' \
      -e 's|\<ip6tables\>|${iptables}/bin/ip6tables|g' \
      -e 's|^ipset |${ipset}/bin/ipset |g' \
      -e 's|\<ipset\>|${ipset}/bin/ipset|g' \
      -e 's|^awk |${gawk}/bin/awk |g' \
      -e 's|\<awk\>|${gawk}/bin/awk|g' \
      -e 's|^curl |${curl}/bin/curl |g' \
      -e 's|\<curl\>|${curl}/bin/curl|g' \
      -e 's|^wget |${wget}/bin/wget |g' \
      -e 's|\<wget\>|${wget}/bin/wget|g' \
      {} \;
    
    # Патчим init скрипт и functions
    for file in /tmp/zapret-build/init.d/sysv/zapret /tmp/zapret-build/init.d/sysv/functions; do
      if [ -f "$file" ]; then
        sed -i \
          -e 's|^iptables |${iptables}/bin/iptables |g' \
          -e 's|\<iptables\>|${iptables}/bin/iptables|g' \
          -e 's|^ip6tables |${iptables}/bin/ip6tables |g' \
          -e 's|\<ip6tables\>|${iptables}/bin/ip6tables|g' \
          -e 's|^ipset |${ipset}/bin/ipset |g' \
          -e 's|\<ipset\>|${ipset}/bin/ipset|g' \
          "$file"
      fi
    done
    
    # Полностью отключаем переключение пользователя в файле functions
    # Заменяем всю логику создания USEROPT на пустую строку
    if [ -f "/tmp/zapret-build/init.d/sysv/functions" ]; then
      sed -i \
        -e 's|USEROPT="--user=\$WS_USER"|USEROPT=""|g' \
        -e 's|USEROPT="--uid \$WS_USER:\$WS_USER"|USEROPT=""|g' \
        -e 's|TPWS_OPT_BASE="\$USEROPT"|TPWS_OPT_BASE=""|g' \
        -e 's|NFQWS_OPT_BASE="\$USEROPT --dpi-desync-fwmark=\$DESYNC_MARK"|NFQWS_OPT_BASE="--dpi-desync-fwmark=\$DESYNC_MARK"|g' \
        "/tmp/zapret-build/init.d/sysv/functions"
    fi
    
    # Создаем конфигурационный файл
    echo "Создание конфигурационного файла: ${configName}"
    if [ -f "/tmp/zapret-build/configs/${configName}" ]; then
      cp "/tmp/zapret-build/configs/${configName}" /tmp/zapret-build/config
      echo "Конфигурационный файл ${configName} успешно создан"
    else
      echo "Ошибка: конфигурационный файл ${configName} не найден"
      echo "Доступные конфигурации:"
      ls -la /tmp/zapret-build/configs/ || true
      exit 1
    fi
    
    # Теперь копируем обработанные файлы в финальную структуру
    cp -r /tmp/zapret-build/* $out/opt/zapret/
    
    # Очищаем временную папку
    rm -rf /tmp/zapret-build
    
    # Создаем wrapper скрипты для бинарников (они уже готовые)
    makeWrapper $out/opt/zapret/binaries/linux-x86_64/nfqws $out/bin/nfqws \
      --prefix PATH : ${lib.makeBinPath [ iptables ipset coreutils ]}
    
    makeWrapper $out/opt/zapret/binaries/linux-x86_64/tpws $out/bin/tpws \
      --prefix PATH : ${lib.makeBinPath [ iptables ipset coreutils ]}
    
    # Делаем все скрипты исполняемыми
    find $out/opt/zapret -name "*.sh" -exec chmod +x {} \;
    chmod +x $out/opt/zapret/install_easy.sh
    chmod +x $out/opt/zapret/uninstall_easy.sh
    chmod +x $out/opt/zapret/init.d/sysv/zapret
    chmod +x $out/opt/zapret/init.d/sysv/functions
    
    # Убеждаемся что бинарники исполняемые
    chmod +x $out/opt/zapret/binaries/linux-x86_64/nfqws
    chmod +x $out/opt/zapret/binaries/linux-x86_64/tpws
    
    # Создаем симлинки в nfq/ и tpws/ папки как в оригинале
    ln -sf $out/opt/zapret/binaries/linux-x86_64/nfqws $out/opt/zapret/nfq/nfqws
    ln -sf $out/opt/zapret/binaries/linux-x86_64/tpws $out/opt/zapret/tpws/tpws
    
    runHook postInstall
  '';

  meta = with lib; {
    description = "DPI bypass multi platform";
    homepage = "https://github.com/bol-van/zapret";
    license = licenses.mit;
    maintainers = [ ];
    platforms = platforms.linux;
  };
} 

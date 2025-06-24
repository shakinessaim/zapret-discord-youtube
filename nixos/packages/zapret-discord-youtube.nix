{ lib
, stdenv
, fetchurl
, makeWrapper
, iptables
, ipset
, coreutils
, bash
, gawk
, curl
, wget
}:

stdenv.mkDerivation rec {
  pname = "zapret";
  version = "71.1.1";

  src = fetchurl {
    url = "https://github.com/bol-van/zapret/releases/download/v${version}/zapret-v${version}.tar.gz";
    sha256 = "sha256-LeDotLFH8Rml4kiXebig1jGUROWDst18HU1bC8+4djU=";
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
    
    # Копируем все файлы zapret в /opt/zapret структуру
    cp -r * $out/opt/zapret/
    
    # Создаем wrapper скрипты для бинарников (они уже готовые)
    makeWrapper $out/opt/zapret/nfq/nfqws $out/bin/nfqws \
      --prefix PATH : ${lib.makeBinPath [ iptables ipset coreutils ]}
    
    makeWrapper $out/opt/zapret/tpws/tpws $out/bin/tpws \
      --prefix PATH : ${lib.makeBinPath [ iptables ipset coreutils ]}
    
    # Делаем все скрипты исполняемыми
    find $out/opt/zapret -name "*.sh" -exec chmod +x {} \;
    chmod +x $out/opt/zapret/install_easy.sh
    chmod +x $out/opt/zapret/uninstall_easy.sh
    chmod +x $out/opt/zapret/init.d/sysv/zapret
    
    # Убеждаемся что бинарники исполняемые
    chmod +x $out/opt/zapret/nfq/nfqws
    chmod +x $out/opt/zapret/tpws/tpws
    
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
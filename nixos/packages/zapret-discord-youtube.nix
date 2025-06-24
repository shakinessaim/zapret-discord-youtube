{ lib
, stdenv
, src
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
  version = "latest";

  inherit src; # Используем src из flake input

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

  installPhase = ''
    runHook preInstall
    
    mkdir -p $out/bin
    mkdir -p $out/share/zapret
    
    # Копируем все файлы zapret
    cp -r * $out/share/zapret/
    
    # Создаем wrapper скрипты
    makeWrapper $out/share/zapret/nfqws/nfqws $out/bin/nfqws \
      --prefix PATH : ${lib.makeBinPath [ iptables ipset coreutils ]}
    
    makeWrapper $out/share/zapret/tpws/tpws $out/bin/tpws \
      --prefix PATH : ${lib.makeBinPath [ iptables ipset coreutils ]}
    
    # Делаем скрипты исполняемыми
    chmod +x $out/share/zapret/install_easy.sh
    chmod +x $out/share/zapret/uninstall_easy.sh
    
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
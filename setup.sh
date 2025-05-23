#!/bin/bash

# Функция для установки wget/git с использованием nala (Debian/Ubuntu)
install_with_nala() {
  sudo nala update
  sudo nala install -y wget git
}

# Функция для установки wget/git с использованием apt (Debian/Ubuntu)
install_with_apt() {
  sudo apt update
  sudo apt install -y wget git
}

# Функция для установки wget/git с использованием yum (CentOS/Fedora)
install_with_yum() {
  sudo yum install -y wget git
}

# Функция для установки wget/git с использованием dnf (Fedora)
install_with_dnf() {
  sudo dnf install -y wget  git
}

# Функция для установки wget/git с использованием pacman (Arch Linux)
install_with_pacman() {
  sudo pacman -Sy --noconfirm wget git 
}

# Функция для установки wget/git с использованием zypper (openSUSE)
install_with_zypper() {
  sudo zypper install -y wget git
}

# Функция для установки wget/git и других пакетов с использованием xbps (Void Linux)
install_with_xbps() {
  sudo xbps-install -A wget git ipset iptables nftables cronie
}

# Функция для установки wget/git с использованием slapt-get (Slackware)
install_with_slapt-get() {
  sudo slapt-get -i --no-prompt wget git
}

# Определяем пакетный менеджер для установки wget
if command -v apt &>/dev/null; then
  echo "Обнаружен apt, устанавливаем wget и git..."
  install_with_apt
elif command -v yum &>/dev/null; then
  echo "Обнаружен yum, устанавливаем wget и git..."
  install_with_yum
elif command -v dnf &>/dev/null; then
  echo "Обнаружен dnf, устанавливаем wget и git..."
  install_with_dnf
elif command -v pacman &>/dev/null; then
  echo "Обнаружен pacman, устанавливаем wget и git..."
  install_with_pacman
elif command -v zypper &>/dev/null; then
  echo "Обнаружен zypper, устанавливаем wget и git..."
  install_with_zypper
elif command -v xbps-install &>/dev/null; then
  echo "Обнаружен xbps, устанавливаем wget и git..."
  install_with_xbps
elif command -v slapt-get &>/dev/null; then
  echo "Обнаружен slapt-get, устанавливаем wget и git..."
  install_with_slapt-get
else
  echo "Не удалось определить пакетный менеджер."
  
  # Проверяем, установлены ли wget и git уже
  if command -v wget &>/dev/null && command -v git &>/dev/null; then
    echo "wget и git уже установлены, продолжаем..."
  else
    echo "Необходимо установить wget и git вручную."
    exit 1
  fi
fi

# Создаем временную директорию, если она не существует
mkdir -p "$HOME/tmp"
# Удаление архива с запретом на всякий
rm -rf "$HOME/tmp/*"

# Бэкап запрета если есть
if [ -d "/opt/zapret" ]; then
  echo "Создание резервной копии существующего zapret..."
  sudo cp -r "/opt/zapret" "/opt/zapret.bak"
fi
sudo rm -rf "/opt/zapret"

# Получение последней версии zapret с GitHub API
echo "Определение последней версии zapret..."
ZAPRET_VERSION=$(curl -s "https://api.github.com/repos/bol-van/zapret/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

if [ -z "$ZAPRET_VERSION" ]; then
  echo "Не удалось получить версию через GitHub API. Используем git ls-remote..."
  
  # Получить все теги, отсортировать их по версии и выбрать последний
  ZAPRET_VERSION=$(git ls-remote --tags https://github.com/bol-van/zapret.git | 
                  grep -v '\^{}' | # Исключаем аннотированные теги
                  awk -F/ '{print $NF}' | # Извлекаем только имя тега
                  sort -V | # Сортируем по версии
                  tail -n 1) # Берем последний тег
  
  if [ -z "$ZAPRET_VERSION" ]; then
    echo "Ошибка: не удалось определить последнюю версию zapret через git ls-remote."
    exit 1
  fi
fi

echo "Последняя версия zapret: $ZAPRET_VERSION"

# Закачка последнего релиза bol-van/zapret
echo "Скачивание последнего релиза zapret..."
if ! wget -O "$HOME/tmp/zapret-$ZAPRET_VERSION.tar.gz" "https://github.com/bol-van/zapret/releases/download/$ZAPRET_VERSION/zapret-$ZAPRET_VERSION.tar.gz"; then
  echo "Ошибка: не удалось скачать zapret."
  exit 1
fi

# Распаковка архива
echo "Распаковка zapret..."
if ! tar -xvf "$HOME/tmp/zapret-$ZAPRET_VERSION.tar.gz" -C "$HOME/tmp"; then
  echo "Ошибка: не удалось распаковать zapret."
  exit 1
fi

# Версия без 'v' в начале для работы с директорией
ZAPRET_DIR_VERSION=$(echo $ZAPRET_VERSION | sed 's/^v//')
echo "Определение пути распакованного архива..."

# Проверяем наличие директорий с разными вариантами именования
if [ -d "$HOME/tmp/zapret-$ZAPRET_DIR_VERSION" ]; then
  ZAPRET_EXTRACT_DIR="$HOME/tmp/zapret-$ZAPRET_DIR_VERSION"
elif [ -d "$HOME/tmp/zapret-$ZAPRET_VERSION" ]; then
  ZAPRET_EXTRACT_DIR="$HOME/tmp/zapret-$ZAPRET_VERSION"
else
  # Если не нашли конкретные варианты, ищем любую папку zapret-*
  ZAPRET_EXTRACT_DIR=$(find "$HOME/tmp" -type d -name "zapret-*" | head -n 1)
  if [ -z "$ZAPRET_EXTRACT_DIR" ]; then
    echo "Ошибка: не удалось найти распакованную директорию zapret."
    echo "Содержимое $HOME/tmp:"
    ls -la "$HOME/tmp"
    exit 1
  fi
fi

echo "Найден распакованный каталог: $ZAPRET_EXTRACT_DIR"

# Перемещение zapret в /opt/zapret
echo "Перемещение zapret в /opt/zapret..."
if ! sudo mv "$ZAPRET_EXTRACT_DIR" /opt/zapret; then
  echo "Ошибка: не удалось переместить zapret в /opt/zapret."
  exit 1
fi

# Клонирование репозитория с конфигами
echo "Клонирование репозитория с конфигами..."
if ! git clone https://github.com/kartavkun/zapret-discord-youtube.git "$HOME/zapret-configs"; then
  rm -rf $HOME/zapret-configs
  if ! git clone https://github.com/kartavkun/zapret-discord-youtube.git "$HOME/zapret-configs"; then
    echo "Ошибка: не удалось клонировать репозиторий с конфигами."
  exit 1
  fi
fi

# Копирование hostlists
echo "Копирование hostlists..."
if ! cp -r "$HOME/zapret-configs/hostlists" /opt/zapret/hostlists; then
  echo "Ошибка: не удалось скопировать hostlists."
  exit 1
fi

# Настройка IP forwarding для WireGuard
echo "Проверка и настройка IP forwarding для WireGuard..."
if [ ! -f "/etc/sysctl.d/99-sysctl.conf" ]; then
  echo "Создание конфигурационного файла /etc/sysctl.d/99-sysctl.conf..."
  echo "# Конфигурация для zapret" | sudo tee /etc/sysctl.d/99-sysctl.conf > /dev/null
  echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.d/99-sysctl.conf > /dev/null
else
  # Проверяем, содержит ли файл уже параметр ip_forward
  if ! grep -q "net.ipv4.ip_forward=1" /etc/sysctl.d/99-sysctl.conf; then
    echo "Добавление параметра net.ipv4.ip_forward=1 в /etc/sysctl.d/99-sysctl.conf..."
    echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.d/99-sysctl.conf > /dev/null
  else
    echo "Параметр net.ipv4.ip_forward=1 уже установлен"
  fi
fi

# Применяем настройки без перезагрузки
sudo sysctl -p /etc/sysctl.d/99-sysctl.conf

# Запуск второго скрипта
echo "Запуск install.sh..."
if ! bash "$HOME/zapret-configs/install.sh"; then
  echo "Ошибка: не удалось запустить install.sh."
  exit 1
fi

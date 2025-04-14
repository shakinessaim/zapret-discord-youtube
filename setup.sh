#!/bin/bash

# Функция для установки wget/curl с использованием nala (Debian/Ubuntu)
install_with_nala() {
  sudo nala update
  sudo nala install -y wget curl git
}

# Функция для установки wget/curl с использованием apt (Debian/Ubuntu)
install_with_apt() {
  sudo apt update
  sudo apt install -y wget curl git
}

# Функция для установки wget/curl с использованием yum (CentOS/Fedora)
install_with_yum() {
  sudo yum install -y wget curl git
}

# Функция для установки wget/curl с использованием dnf (Fedora)
install_with_dnf() {
  sudo dnf install -y wget curl git
}

# Функция для установки wget/curl с использованием pacman (Arch Linux)
install_with_pacman() {
  sudo pacman -Sy --noconfirm wget curl git
}

# Функция для установки wget/curl с использованием zypper (openSUSE)
install_with_zypper() {
  sudo zypper install -y wget curl git
}

# Определяем пакетный менеджер для установки wget
if command -v apt &>/dev/null; then
  echo "Обнаружен apt, устанавливаем wget и curl..."
  install_with_apt
elif command -v yum &>/dev/null; then
  echo "Обнаружен yum, устанавливаем wget и curl..."
  install_with_yum
elif command -v dnf &>/dev/null; then
  echo "Обнаружен dnf, устанавливаем wget и curl..."
  install_with_dnf
elif command -v pacman &>/dev/null; then
  echo "Обнаружен pacman, устанавливаем wget и curl..."
  install_with_pacman
elif command -v zypper &>/dev/null; then
  echo "Обнаружен zypper, устанавливаем wget и curl..."
  install_with_zypper
else
  echo "Не удалось определить пакетный менеджер. Установите wget и curl вручную."
  exit 1
fi

# Проверка успешной установки wget
if ! command -v wget &>/dev/null; then
  echo "Ошибка: wget не установлен. Установите его вручную."
  exit 1
fi

echo "wget успешно установлен!"

# Проверка успешной установки curl
if ! command -v curl &>/dev/null; then
  echo "Ошибка: curl не установлен. Установите его вручную."
  exit 1
fi

echo "curl успешно установлен!"

# Создаем временную директорию, если она не существует
mkdir -p "$HOME/tmp"
# Удаление архива с запретом на всякий
rm -rf "$HOME/tmp/*"

# Бэкап запрета если есть
sudo cp "/opt/zapret" "/opt/zapret.bak"
sudo rm -rf "/opt/zapret"

# Получение последней версии zapret с GitHub API
ZAPRET_VERSION=$(curl -s "https://api.github.com/repos/bol-van/zapret/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

if [ -z "$ZAPRET_VERSION" ]; then
  echo "Ошибка: не удалось определить последнюю версию zapret."
  exit 1
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

# Запуск второго скрипта
echo "Запуск install.sh..."
if ! bash "$HOME/zapret-configs/install.sh"; then
  echo "Ошибка: не удалось запустить install.sh."
  exit 1
fi

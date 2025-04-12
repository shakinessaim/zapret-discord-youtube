#!/bin/bash

clear

# Функция для установки конфига по умолчанию
default_install() {
  echo "Копирование конфига 50-discord..."
  if ! cp /opt/zapret/init.d/custom.d.examples.linux/50-discord /opt/zapret/init.d/sysv/custom.d/; then
    echo "Ошибка: не удалось скопировать 50-discord."
    exit 1
  fi

  if [ -f "/sys/fs/selinux/enforce" ]; then 
	echo "Обнаружены следы selinux. Применяем правила."
	./module/fixfilecontext.sh
  fi
  
  echo "Запуск install_easy.sh..."
  if ! /opt/zapret/install_easy.sh; then
    echo "Ошибка: не удалось запустить install_easy.sh."
  fi
}

# Функции для установки различных конфигов
general() {
  echo "Установка конфига general..."
  if ! cp "$HOME/zapret-configs/configs/general" /opt/zapret/config; then
    echo "Ошибка: не удалось скопировать конфиг general."
    exit 1
  fi
  default_install
}

general_ALT() {
  echo "Установка конфига general(ALT)..."
  if ! cp "$HOME/zapret-configs/configs/general(ALT)" /opt/zapret/config; then
    echo "Ошибка: не удалось скопировать конфиг general(ALT)."
    exit 1
  fi
  default_install
}

general_ALT2() {
  echo "Установка конфига general(ALT2)..."
  if ! cp "$HOME/zapret-configs/configs/general(ALT2)" /opt/zapret/config; then
    echo "Ошибка: не удалось скопировать конфиг general(ALT2)."
    exit 1
  fi
  default_install
}

general_ALT3() {
  echo "Установка конфига general(ALT3)..."
  if ! cp "$HOME/zapret-configs/configs/general(ALT3)" /opt/zapret/config; then
    echo "Ошибка: не удалось скопировать конфиг general(ALT3)."
    exit 1
  fi
  default_install
}

general_ALT4() {
  echo "Установка конфига general(ALT4)..."
  if ! cp "$HOME/zapret-configs/configs/general(ALT4)" /opt/zapret/config; then
    echo "Ошибка: не удалось скопировать конфиг general(ALT4)."
    exit 1
  fi
  default_install
}

general_ALT5() {
  echo "Установка конфига general(ALT5)..."
  if ! cp "$HOME/zapret-configs/configs/general(ALT5)" /opt/zapret/config; then
    echo "Ошибка: не удалось скопировать конфиг general(ALT5)."
    exit 1
  fi
  default_install
}

general_MGTS() {
  echo "Установка конфига general(МГТС)..."
  if ! cp "$HOME/zapret-configs/configs/general(МГТС)" /opt/zapret/config; then
    echo "Ошибка: не удалось скопировать конфиг general(МГТС)."
    exit 1
  fi
  default_install
}

general_MGTS2() {
  echo "Установка конфига general(МГТС2)..."
  if ! cp "$HOME/zapret-configs/configs/general(МГТС2)" /opt/zapret/config; then
    echo "Ошибка: не удалось скопировать конфиг general(МГТС2)."
    exit 1
  fi
  default_install
}

# Меню для выбора конфига
echo "Выберите конфиг для установки:"
select config in "general" "general_ALT" "general_ALT2" "general_ALT3" "general_ALT4" "general_ALT5" "general_MGTS" "general_MGTS2"; do
  case $config in
    "general")
      general
      break
      ;;
    "general_ALT")
      general_ALT
      break
      ;;
    "general_ALT2")
      general_ALT2
      break
      ;;
    "general_ALT3")
      general_ALT3
      break
      ;;
    "general_ALT4")
      general_ALT4
      break
      ;;
    "general_ALT5")
      general_ALT5
      break
      ;;
    "general_MGTS")
      general_MGTS
      break
      ;;
    "general_MGTS2")
      general_MGTS2
      break
      ;;
    *)
      echo "Неверный выбор. Пожалуйста, выберите снова."
      ;;
  esac
done

echo "Установка завершена успешно!"

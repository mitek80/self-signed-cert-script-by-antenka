#!/bin/bash

set -euo pipefail

# Цвета
GREEN="\033[0;32m"
RED="\033[0;31m"
CYAN="\033[0;36m"
RESET="\033[0m"

# Лог
LOG_FILE="/var/log/3x-ui_install.log"
exec > >(tee -i "$LOG_FILE")
exec 2>&1

# Функция ошибки
function error_exit {
  echo -e "${RED}Ошибка: $1${RESET}"
  exit 1
}

if [[ $EUID -ne 0 ]]; then
  error_exit "Скрипт должен быть запущен root. Используйте sudo."
fi

# Устанавливаем зависимости
function install_dependency {
  local pkg="$1"
  if ! command -v "$pkg" &>/dev/null; then
    apt update && apt install -y "$pkg" || error_exit "Не удалось установить $pkg"
  fi
}

install_dependency "openssl"
install_dependency "qrencode"

TMP_INSTALL_SCRIPT="/tmp/install_3x_ui.sh"
KNOWN_HASH="<SHA256_HASH>"

curl -Ls https://raw.githubusercontent.com/MHSanaei/3x-ui/master/install.sh -o "$TMP_INSTALL_SCRIPT" || error_exit "Не удалось загрузить скрипт."
CALCULATED_HASH=$(sha256sum "$TMP_INSTALL_SCRIPT" | awk '{print $1}')

if [[ "$CALCULATED_HASH" != "$KNOWN_HASH" ]]; then
  error_exit "Файл 3x-ui подделан!"
fi

bash "$TMP_INSTALL_SCRIPT" || error_exit "Не удалось установить 3x-ui."
rm -f "$TMP_INSTALL_SCRIPT"

# Генерация сертификатов ED25519
CERT_DIR="/etc/ssl/self_signed_cert"
CERT_NAME="self_signed"
DAYS_VALID=3650

mkdir -p "$CERT_DIR"
CERT_PATH="$CERT_DIR/$CERT_NAME.crt"
KEY_PATH="$CERT_DIR/$CERT_NAME.key"

read -p "Введите домен для сертификата (по умолчанию example.com): " DOMAIN
DOMAIN=$(echo "${DOMAIN:-example.com}" | tr -d ';|&<>')

# Генерация ED25519-ключей
openssl genpkey -algorithm ED25519 -out "$KEY_PATH" || error_exit "Ошибка создания ключа ED25519"
openssl req -x509 -key "$KEY_PATH" -out "$CERT_PATH" -days "$DAYS_VALID" -subj "/CN=$DOMAIN" || error_exit "Ошибка сертификата ED25519"

chmod 600 "$CERT_PATH" "$KEY_PATH"
chown root:root "$CERT_PATH" "$KEY_PATH"

echo -e "${GREEN}Сертификат на базе ED25519 сгенерирован успешно!${RESET}"



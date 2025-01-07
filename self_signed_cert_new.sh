#!/bin/bash

# Устанавливаем 3x-ui панель для VLESS и сертификаты на 10 лет

# Проверка прав
if [[ $EUID -ne 0 ]]; then
  echo "Скрипт должен быть запущен с правами root. Используйте: sudo $0"
  exit 1
fi

# Установка OpenSSL
if ! command -v openssl &> /dev/null; then
  sudo apt update && sudo apt install -y openssl
  if [ $? -ne 0 ]; then
    echo "Не удалось установить OpenSSL."
    exit 1
  fi
fi

# Установка qrencode
if ! command -v qrencode &> /dev/null; then
  sudo apt update && sudo apt install -y qrencode
  if [ $? -ne 0 ]; then
    echo "Не удалось установить qrencode."
    exit 1
  fi
fi

# Установка 3X-UI
curl -Ls https://raw.githubusercontent.com/MHSanaei/3x-ui/master/install.sh -o /tmp/install.sh
if [ $? -ne 0 ] || [ ! -s /tmp/install.sh ]; then
  echo "Ошибка: не удалось загрузить скрипт установки 3X-UI"
  exit 1
fi
bash /tmp/install.sh
if [ $? -ne 0 ]; then
  echo "Ошибка: установка 3X-UI завершилась неудачно"
  exit 1
fi

# Запуск 3X-UI
systemctl daemon-reload
if systemctl list-units --full -all | grep -Fq 'x-ui.service'; then
  systemctl enable x-ui
  systemctl start x-ui
else
  if ! command -v x-ui &> /dev/null; then
    echo "Ошибка: x-ui не установлен корректно"
    exit 1
  fi
  x-ui
fi

# Генерация сертификатов
CERT_DIR="/etc/ssl/self_signed_cert"
CERT_NAME="self_signed"
DAYS_VALID=3650
mkdir -p "$CERT_DIR"

CERT_PATH="$CERT_DIR/$CERT_NAME.crt"
KEY_PATH="$CERT_DIR/$CERT_NAME.key"

read -p "Введите домен для сертификата (по умолчанию example.com): " DOMAIN
DOMAIN=${DOMAIN:-example.com}

openssl req -x509 -nodes -days $DAYS_VALID -newkey rsa:2048 \
  -keyout "$KEY_PATH" \
  -out "$CERT_PATH" \
  -subj "/C=US/ST=State/L=City/O=Organization/OU=Department/CN=$DOMAIN"

if [ -f "$CERT_PATH" ] && [ -f "$KEY_PATH" ]; then
  echo "SSL CERTIFICATE PATH: $CERT_PATH"
  echo "SSL KEY PATH: $KEY_PATH"
else
  echo "Ошибка: сертификаты не удалось создать"
  exit 1
fi

# Финальное сообщение
echo "============================================================"
echo "   Установка завершена, ключи сгенерированы!"
echo "   Осталось только пути ключей прописать в панели управления 3x-ui"

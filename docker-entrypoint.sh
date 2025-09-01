#!/usr/bin/env bash
# docker-entrypoint.sh - przygotowanie /var/log/MockService.log i drop do 'tester'

set -euo pipefail

LOG_FILE="/var/log/MockService.log"

# Upewnij się, że użytkownik istnieje (gdy layer cache był starszy)
id tester >/dev/null 2>&1 || useradd -u 1000 -m tester || true

# Przygotuj log w ZAMONTOWANYM wolumenie /var/log
mkdir -p /var/log
touch "$LOG_FILE"
chown tester:tester "$LOG_FILE"
chmod 664 "$LOG_FILE"

# Uruchom właściwą komendę jako 'tester'
# (działa i dla 'CMD' z Dockerfile i dla 'command:' z compose)
exec su -s /bin/bash -c "$*" tester

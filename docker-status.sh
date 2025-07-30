#!/usr/bin/env bash

cd "$(dirname "$0")" || exit 1

echo "Status kontenerów Compose w projekcie:"
docker compose ps --format "table {{.Name}}\t{{.State}}\t{{.Status}}"
#!/usr/bin/env bash
# docker-status.sh — status usług/ kontenerów dla profili dev i ci

set -euo pipefail

cd "$(dirname "$0")" || {
  echo ">>> Błąd: nie mogę wejść do katalogu skryptu."
  exit 1
}

IMAGE_NAME="docker-api-tests"
DEV_NAME="docker-api-tests-dev"
CI_NAME="docker-api-tests-ci"
ENV_FILE="versions.env"

compose() { docker compose --env-file "$ENV_FILE" "$@"; }

if [ ! -f "$ENV_FILE" ]; then
  echo ">>> Błąd: brak pliku $ENV_FILE obok skryptu."
  exit 1
fi

echo ">>> Status usług Compose (wszystkie uruchomione kontenery projektu):"
compose ps --format "table {{.Name}}\t{{.State}}\t{{.Status}}"

show_details() {
  local NAME="$1"
  echo
  echo ">>> Szczegóły kontenera: $NAME"
  if ! docker inspect "$NAME" >/dev/null 2>&1; then
    echo "    State  : not-found"
    echo "    Health : n/a"
    echo "    Ports  : n/a"
    return
  fi
  local STATUS HEALTH PORTS
  STATUS="$(docker inspect -f '{{.State.Status}}' "$NAME" 2>/dev/null || echo "unknown")"
  HEALTH="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{end}}' "$NAME" 2>/dev/null || true)"
  PORTS="$(docker port "$NAME" 2>/dev/null || true)"
  echo "    State  : $STATUS"
  echo "    Health : ${HEALTH:-n/a}"
  echo "    Ports  : ${PORTS:-n/a}"
}

show_details "$DEV_NAME"
show_details "$CI_NAME"

echo
echo ">>> Obraz: $IMAGE_NAME"
if docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
  docker image inspect "$IMAGE_NAME" --format '    ID: {{.Id}} | Size: {{.Size}} | Created: {{.Created}}'
else
  echo "    (obraz nie istnieje lokalnie)"
fi

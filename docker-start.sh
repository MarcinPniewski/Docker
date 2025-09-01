#!/usr/bin/env bash
# docker-start.sh — start/rekonfiguracja kontenera (profile: dev/ci)

set -euo pipefail

cd "$(dirname "$0")" || {
  echo ">>> Błąd: nie mogę wejść do katalogu skryptu."
  exit 1
}

IMAGE_NAME="docker-api-tests"
DEV_NAME="docker-api-tests-dev"
CI_NAME="docker-api-tests-ci"
ENV_FILE="versions.env"

# ---------- helpers ----------
tolower() { printf "%s" "$1" | tr '[:upper:]' '[:lower:]'; }

compose() {
  # $PROFILE może być puste (dev) albo "ci"
  if [[ -n "${PROFILE:-}" ]]; then
    docker compose --env-file "$ENV_FILE" --profile "$PROFILE" "$@"
  else
    docker compose --env-file "$ENV_FILE" "$@"
  fi
}

require_env() {
  [[ -f "$ENV_FILE" ]] || { echo ">>> Błąd: brak pliku $ENV_FILE obok skryptu."; exit 1; }
  local required=(JAVA_VERSION SOAPUI_VERSION NODE_VERSION MOCKSERVICE_VERSION TESTS_SOAPUI_VERSION)
  local missing=()
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  for v in "${required[@]}"; do
    eval "val=\${$v:-}"
    [[ -z "$val" ]] && missing+=("$v")
  done
  if (( ${#missing[@]} > 0 )); then
    echo ">>> Błąd: w $ENV_FILE brakuje wartości dla: ${missing[*]}"
    exit 1
  fi
}

wait_ready() {
  local NAME="$1"
  echo ">>> Czekam na gotowość kontenera $NAME…"
  for _ in {1..60}; do
    local status health
    status="$(docker inspect -f '{{.State.Status}}' "$NAME" 2>/dev/null || true)"
    health="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{end}}' "$NAME" 2>/dev/null || true)"
    if [[ -z "$health" && "$status" == "running" ]]; then break; fi
    if [[ "$health" == "healthy" ]]; then break; fi
    sleep 1
  done
  local status
  status="$(docker inspect -f '{{.State.Status}}' "$NAME" 2>/dev/null || echo "")"
  if [[ "$status" != "running" ]]; then
    echo ">>> Błąd: kontener $NAME nie jest uruchomiony (status: ${status:-unknown})."
    exit 1
  fi
}

open_shell() {
  local NAME="$1"
  echo ">>> Otwieram bash jako użytkownik tester w $NAME…"
  if ! docker exec -it -u 1000:1000 "$NAME" bash 2>/dev/null; then
    echo ">>> Uwaga: nie udało się wejść jako tester — otwieram jako root."
    docker exec -it "$NAME" bash
  fi
}

# NIE usuwaj sieci drugiego profilu — tylko zatrzymaj usługi
stop_other_profile() {
  if [[ "${PROFILE:-}" == "ci" ]]; then
    echo ">>> Gaszę usługi profilu dev (bez usuwania sieci/volumenów)…"
    docker compose --env-file "$ENV_FILE" --profile dev stop || true
  else
    echo ">>> Gaszę usługi profilu ci (bez usuwania sieci/volumenów)…"
    docker compose --env-file "$ENV_FILE" --profile ci stop || true
  fi
}

# ---------- tryb --silent (CI) ----------
if [[ "${1:-}" == "--silent" ]]; then
  require_env
  PROFILE="ci"
  echo ">>> [CI] Gasi profil dev (tylko stop)…"
  docker compose --env-file "$ENV_FILE" --profile dev stop || true
  echo ">>> [CI] Down -v profilu ci (czyści kontenery/sieci/wolumeny)…"
  compose down -v --remove-orphans || true
  echo ">>> [CI] Build (no-cache + pull)…"
  compose build --no-cache --pull
  echo ">>> [CI] Up (force-recreate)…"
  compose up -d --force-recreate --remove-orphans
  wait_ready "$CI_NAME"
  echo ">>> [CI] Gotowe."
  exit 0
fi

# ---------- tryb interaktywny ----------
require_env

read -r -p "Czy chcesz zbudować kontener od nowa? [t/N]: " ODPOWIEDZ
read -r -p "Wybierz profil [dev/ci] (domyślnie dev): " PROF_IN
PROF_IN="$(tolower "${PROF_IN:-dev}")"

case "$PROF_IN" in
  ci)  PROFILE="ci";   CONTAINER_NAME="$CI_NAME"  ;;
  dev) PROFILE="dev";  CONTAINER_NAME="$DEV_NAME" ;;
esac

# uniknij konfliktu portów, ale NIE usuwaj sieci
stop_other_profile

if [[ "$ODPOWIEDZ" =~ ^[Tt]$ ]]; then
  echo ">>> Buduję obraz od nowa (no-cache + pull)…"
  compose build --no-cache --pull
  echo ">>> Uruchamiam kontener (force-recreate)…"
  compose up -d --force-recreate --remove-orphans
else
  echo ">>> Sprawdzam, czy obraz ${IMAGE_NAME}:latest istnieje…"
  if ! docker image inspect "${IMAGE_NAME}:latest" >/dev/null 2>&1; then
    echo ">>> Obraz nie istnieje – buduję i uruchamiam…"
    compose build
    compose up -d --force-recreate --remove-orphans
  else
    echo ">>> Obraz istnieje – uruchamiam (force-recreate, aby odtworzyć sieci)…"
    compose up -d --force-recreate --remove-orphans
  fi
fi

wait_ready "$CONTAINER_NAME"
open_shell "$CONTAINER_NAME"

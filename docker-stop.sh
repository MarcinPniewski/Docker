#!/usr/bin/env bash
# docker-stop.sh — zatrzymanie i czyszczenie środowiska (dev/ci)
# Użycie:
#   ./docker-stop.sh --silent    # zatrzymaj i wyczyść WSZYSTKO (dev+ci) bez pytań
#   ./docker-stop.sh             # menu interaktywne

set -euo pipefail

cd "$(dirname "$0")" || {
  echo ">>> Błąd: nie mogę wejść do katalogu skryptu."
  exit 1
}

IMAGE_NAME="docker-api-tests"
DEV_NAME="docker-api-tests-dev"
CI_NAME="docker-api-tests-ci"
ENV_FILE="versions.env"

VOL_LOGS="docker-api-logs"
VOL_REPORTS="docker-api-reports"

# --- helpers ---

tolower() { printf "%s" "$1" | tr '[:upper:]' '[:lower:]'; }

compose() {
  # $1 może być pusty (dev), "ci" albo "dev"
  local prof="${1:-}"
  shift || true
  if [ -n "$prof" ]; then
    docker compose --env-file "$ENV_FILE" --profile "$prof" "$@"
  else
    docker compose --env-file "$ENV_FILE" "$@"
  fi
}

require_env() {
  if [ ! -f "$ENV_FILE" ]; then
    echo ">>> Błąd: brak pliku $ENV_FILE obok skryptu."
    exit 1
  fi
}

stop_only() {
  local prof="$1"
  echo ">>> [${prof:-dev}] STOP usług (bez usuwania)…"
  compose "$prof" stop || true
}

down_basic() {
  local prof="$1"
  echo ">>> [${prof:-dev}] DOWN (usuń kontenery + sieci)…"
  # dev: bez -v (bind-mounty), ci: zazwyczaj też bez -v w opcji 2)
  compose "$prof" down --remove-orphans || true
}

down_with_volumes() {
  local prof="$1"
  echo ">>> [${prof:-dev}] DOWN -v (usuń kontenery + sieci + wolumeny profilu)…"
  compose "$prof" down -v --remove-orphans || true
}

remove_image() {
  echo ">>> Usuwam obraz: ${IMAGE_NAME}:latest (jeśli istnieje)…"
  if docker image inspect "${IMAGE_NAME}:latest" >/dev/null 2>&1; then
    docker image rm "${IMAGE_NAME}:latest" || true
  else
    echo "    (obraz nie istnieje lokalnie)"
  fi
}

clean_named_volumes() {
  # bezpiecznie: tylko twoje nazwane wolumeny
  for v in "$VOL_LOGS" "$VOL_REPORTS"; do
    if docker volume inspect "$v" >/dev/null 2>&1; then
      echo ">>> Usuwam wolumen: $v"
      docker volume rm "$v" || true
    fi
  done
}

prune_build_cache() {
  echo ">>> Czyszczę cache buildera (buildx)…"
  docker builder prune -f || true
  echo ">>> Czyszczę osierocone obrazy (dangling)…"
  docker image prune -f || true
}

# --- tryb silent (full clean dev+ci) ---
if [ "${1:-}" = "--silent" ]; then
  require_env
  echo ">>> [SILENT] pełne czyszczenie dev + ci…"
  # dev
  down_with_volumes "dev"      # -v nie zaszkodzi (dev nie ma nazwanych wolumenów)
  # ci
  down_with_volumes "ci"
  # obraz + cache + nazwane wolumeny (na wszelki wypadek)
  remove_image
  clean_named_volumes
  prune_build_cache
  echo ">>> [SILENT] gotowe."
  exit 0
fi

# --- tryb interaktywny ---
require_env

echo "Wybierz profil [dev/ci/oba] (domyślnie dev): "
read -r PROF_IN
PROF_IN="$(tolower "${PROF_IN:-dev}")"

case "$PROF_IN" in
  dev|ci|oba) ;;
  *) PROF_IN="dev" ;;
esac

echo "Wybierz akcję:"
echo "  1) tylko zatrzymaj kontener(y)"
echo "  2) zatrzymaj i usuń obraz"
echo "  3) zatrzymaj i WYCZYŚĆ WSZYSTKO (kontenery, sieci, wolumeny nazwane, obraz, cache)"
read -r -p "Numer [1/2/3]: " CHOICE

case "$CHOICE" in
  1)
    if [ "$PROF_IN" = "oba" ]; then
      stop_only "dev"
      stop_only "ci"
    else
      stop_only "$PROF_IN"
    fi
    ;;
  2)
    if [ "$PROF_IN" = "oba" ]; then
      down_basic "dev"
      down_basic "ci"
    else
      down_basic "$PROF_IN"
    fi
    remove_image
    ;;
  3)
    if [ "$PROF_IN" = "oba" ]; then
      down_with_volumes "dev"
      down_with_volumes "ci"
    else
      # w dev -v nie usuwa bindów, ale czyści ewentualne nazwane wolumeny,
      # w ci usuwa wolumeny nazwane (logs/reports)
      down_with_volumes "$PROF_IN"
    fi
    remove_image
    clean_named_volumes
    prune_build_cache
    ;;
  *)
    echo ">>> Nieprawidłowy wybór."
    exit 1
    ;;
esac

echo ">>> Zakończono."

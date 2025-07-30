#!/usr/bin/env bash

cd "$(dirname "$0")"

IMAGE_NAME="docker-api-tests"
CONTAINER_NAME="docker-api-tests-instance"

echo -n "Czy chcesz zbudować kontener od nowa? [t/N]: "
read -r ODPOWIEDZ

if [[ "$ODPOWIEDZ" =~ ^[Tt]$ ]]; then
    echo ">>> Buduję obraz od nowa..."
    docker compose up --build -d
else
    echo ">>> Sprawdzam, czy obraz $IMAGE_NAME istnieje..."
    if ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
        echo ">>> Obraz nie istnieje – buduję..."
        docker compose up --build -d
    else
        echo ">>> Obraz istnieje – uruchamiam bez budowania..."
        docker compose up -d
    fi
fi

echo ">>> Otwieram bash wewnątrz kontenera $CONTAINER_NAME..."
docker exec -it "$CONTAINER_NAME" bash
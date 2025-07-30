FROM python:3.11-alpine

LABEL org.opencontainers.image.title="docker-api-tests" \
      org.opencontainers.image.description="Kontener do testów API" \
      org.opencontainers.image.version="1.0" \
      org.opencontainers.image.authors="Marcin Pniewski" \
      org.opencontainers.image.source="https://github.com/MarcinPniewski/Docker" \
      org.opencontainers.image.licenses="SEE LICENSE IN LICENSE"

# --- Instalacja wymaganych narzędzi ---
RUN apk add --no-cache \
    bash \
    curl \
    git

# --- Kopiowanie mocka z hosta ---
#COPY /MockService /opt/MockService

# --- Klonowanie repozytorium mocka bez historii git ---
RUN git clone --depth 1 https://github.com/MarcinPniewski/MockService.git /opt/MockService

# --- Instalacja zależności Pythona ---
WORKDIR /opt/MockService
RUN pip3 install --no-cache-dir -r requirements.txt

# --- Domyślna komenda — bash do interakcji ---
CMD ["bash"]
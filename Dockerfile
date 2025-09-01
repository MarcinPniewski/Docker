FROM python:3.11-slim

LABEL org.opencontainers.image.title="docker-api-tests" \
      org.opencontainers.image.description="Kontener do testów API" \
      org.opencontainers.image.version="1.1" \
      org.opencontainers.image.authors="Marcin Pniewski" \
      org.opencontainers.image.source="https://github.com/MarcinPniewski/Docker" \
      org.opencontainers.image.licenses="SEE LICENSE IN LICENSE"

# --- Wersje narzędzi przekazywane jako build-args ---
ARG JAVA_VERSION
ARG SOAPUI_VERSION
ARG NODE_VERSION
ARG MOCKSERVICE_VERSION
ARG TESTS_SOAPUI_VERSION

# --- Zmienne środowiskowe do użycia w czasie działania kontenera ---
ENV \
    JAVA_VERSION=${JAVA_VERSION} \
    SOAPUI_VERSION=${SOAPUI_VERSION} \
    NODE_VERSION=${NODE_VERSION} \
    MOCKSERVICE_VERSION=${MOCKSERVICE_VERSION} \
    TESTS_SOAPUI_VERSION=${TESTS_SOAPUI_VERSION} \
    SOAPUI_HOME=/opt/SoapUI-${SOAPUI_VERSION} \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# --- Katalog roboczy dla pobierania i instalacji ---
WORKDIR /opt

# --- Instalacja JRE, Node.js oraz podstawowych narzędzi + junit-viewer ---
RUN set -eux; \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
       ca-certificates \
       curl \
       wget \
       gnupg \
       git \
       vim \
       tzdata \
       acl \
       openjdk-${JAVA_VERSION}-jre-headless; \
    \
    # Node.js z oficjalnego repozytorium
    curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash -; \
    apt-get install -y --no-install-recommends nodejs; \
    npm i -g xunit-viewer; \
    \
    # Sprzątniecie po apt
    rm -rf /var/lib/apt/lists/*

# --- Instalacja SoapUI i dodanie do PATH ---
RUN set -eux; \
    curl -fsSL "https://dl.eviware.com/soapuios/${SOAPUI_VERSION}/SoapUI-${SOAPUI_VERSION}-linux-bin.tar.gz" \
       | tar -xz -C /opt; \
    ln -sf "${SOAPUI_HOME}/bin/testrunner.sh" /usr/local/bin/testrunner; \
    ln -sf "${SOAPUI_HOME}/bin/mockservicerunner.sh" /usr/local/bin/mockservicerunner

# --- Dostarczenie MockService ---
# Możesz wybrać jedną z opcji:
# 1) Kopiowanie z hosta:
#COPY --chown=root:root MockService /opt/MockService

# 2) Klonowanie repozytorium bez historii:
#RUN git clone --depth 1 https://github.com/MarcinPniewski/MockService.git /opt/MockService

# 3) Pobranie konkretnej wersji z GitHub + czyszczenie:
RUN set -eux; \
    mkdir -p /opt/MockService; \
    curl -fsSL "https://github.com/MarcinPniewski/MockService/archive/refs/tags/${MOCKSERVICE_VERSION}.tar.gz" \
       | tar -xz -C /opt/MockService --strip-components=1; \
    rm -rf /opt/MockService/.github; \
    rm -f  /opt/MockService/.gitignore

# --- Instalacja zależności Pythona dla MockService (jeśli istnieją) ---
WORKDIR /opt/MockService
RUN set -eux; \
    if [ -f requirements.txt ]; then \
       pip install --no-cache-dir -r requirements.txt; \
    fi

# --- Przygotowanie testów SoapUI ---
# Możesz wybrać jedną z opcji:
# 1) Kopiowanie z hosta:
#COPY --chown=root:root SoapUI /opt/tests/SoapUI

# 2) Klonowanie repozytorium bez historii:
#RUN git clone --depth 1 https://github.com/MarcinPniewski/SoapUI.git /opt/tests/SoapUI

# 3) Pobranie konkretnej wersji z GitHub + czyszczenie:
RUN set -eux; \
    mkdir -p /opt/tests/SoapUI; \
    curl -fsSL "https://github.com/MarcinPniewski/SoapUI/archive/refs/tags/${TESTS_SOAPUI_VERSION}.tar.gz" \
       | tar -xz -C /opt/tests/SoapUI --strip-components=1; \
    rm -rf /opt/tests/SoapUI/.github; \
    rm -f  /opt/tests/SoapUI/.gitignore

# --- Utworzenie użytkownika, katalogów na raporty i nadanie praw ---
RUN set -eux; \
    mkdir -p /opt/reports; \
    useradd -u 1000 -m tester; \
    setfacl -m u:tester:rwx /var/log; \
    setfacl -d -m u:tester:rwx /var/log; \
    chown -R tester:tester /opt/MockService /opt/tests /opt/reports

# --- Entrypoint ---
COPY Docker/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh
ENTRYPOINT ["docker-entrypoint.sh"]

WORKDIR /opt/tests

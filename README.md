# Docker — kontener z MockService + testami SoapUI

## Opis
Kontenerowe środowisko do testów API:

- **[MockService](https://github.com/MarcinPniewski/MockService)** (Flask) uruchamiany w kontenerze
- **[SoapUI Open Source](https://www.soapui.org)**
- **[testy SoapUI](https://github.com/MarcinPniewski/SoapUI)** pobierane z repo tagowanego wersją
- **[Java JRE](https://openjdk.org)** (dla SoapUI)
- **[Node.js](https://nodejs.org)** + **[xunit-viewer](https://github.com/lukejpreston/xunit-viewer)** (raporty z testów)
- gotowe profile **dev/ci** oraz skrypty ułatwiające pracę lokalnie i w pipeline’ach

## Struktura projektu

- `.github/workflows/` - workflow tworzący Release na podstawie CHANGELOG
  - `release.yml`
- `Dockerfile`
- `docker-compose.yml`
- `docker-entrypoint.sh`
- `docker-start.sh`
- `docker-stop.sh`
- `docker-status.sh`
- `versions.env`
- `logs/` - log MockService dla profilu dev
  - `MockService.log`
-  `reports/` - raporty z wykonanych testów CLI dla profilu dev
  -  `soapui-console-<YYYYMMDD_24HHMISS>.txt` - zawartość konsoli z przebiegu testu w SoapUI
  -  `soapui-report-<YYYYMMDD_24HHMISS>.html` - przekonwertowany raport generowany przez SoapUI

### Szczegółowo
- `Dockerfile` – buduje obraz (Python 3.11-slim + Java JRE + Node.js + SoapUI + xunit-viewer) + pobiera wskazane tagiem wersje **MockService** i **testów SoapUI** + tworzy użytkownika **tester** (UID 1000)
- `docker-compose.yml` – zawiera dwa serwisy z profilami:
  - `api-tests` (profil **dev**) – bind-mounty `./logs` i `./reports`
  - `api-tests-ci` (profil **ci**) – nazwane wolumeny Dockera
- `versions.env` - definiuje wersje instalowanych/pobieranych komponentów
- `docker-entrypoint.sh` – przed startem aplikacji przygotowuje `/var/log/MockService.log` (na zamontowanym wolumenie) i uruchamia proces jako użytkownik **tester** (UID 1000).
- Skrypty: `docker-start.sh`, `docker-stop.sh`, `docker-status.sh` – wygodne uruchamianie/lifecycle w DEV/CI.

## Wymagania
- Docker Desktop

## Start w trybie DEV

- Przejście do katalogu `Docker/`
- Interaktywny start:

   ```bash
   ./docker-start.sh
   ```

   - pytanie o **rebuild** (`t`/`N`).
   - profil **dev** (domyślnie).

- MockService działa na porcie **8089** (mapowany `8089:8089`):

> W trybie **dev** logi i raporty są tworzone na hoście: `Docker/logs/`, `Docker/reports/`.

## Start w trybie CI

- Przejście do katalogu `Docker/`
- Cichy start:

  ```bash
  ./docker-start.sh --silent
  ```

  Co się dzieje:
  - stop profilu `dev`
  - `down -v` profilu `ci` (czyści kontenery/sieci/wolumeny)
  - `build --no-cache --pull`
  - `up -d --force-recreate --remove-orphans` profilu `ci`

- MockService działa na porcie **8089** (mapowany `8089:8089`):


> W trybie **ci** logi i raporty są tworzone na nazwanych wolumenach:
> 
  - `docker-api-logs` → montowany jako `/var/log`
  - `docker-api-reports` → montowany jako `/opt/reports`

## Licencja
To repozytorium udostępniane jest wyłącznie do celów testowych i edukacyjnych.  
Wszelkie inne formy użycia (modyfikacja, komercja, publikacja) są zabronione.  
Szczegóły w pliku [LICENSE.txt](./LICENSE.txt).
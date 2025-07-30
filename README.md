# Docker – kontener testowy z MockService

## Opis
Projekt zawiera środowisko Docker zbudowane na bazie Alpine, umożliwiające testowanie API z wykorzystaniem prostego serwera mockującego ([MockService](https://github.com/MarcinPniewski/MockService)) opartego na Flask.

MockService uruchamiany jest automatycznie po starcie kontenera i obsługuje zapytania `GET` na podstawie predefiniowanych odpowiedzi tekstowych.
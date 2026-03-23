# Catalog Service

Vollstaendiges Dart-Beispiel fuer einen kleinen Microservice einer digitalen Schulbibliothek.

## Inhalte

- kommentierter HTTP-Server mit `dart:io`
- klare Trennung zwischen Modell, Fachlogik, Repository und HTTP-Schicht
- JSON-API fuer Katalog, Ausleihe und Statistik
- Unit-Tests und HTTP-Integrationstests

## Starten

```bash
dart run bin/catalog_service.dart
```

Optional ueber Umgebungsvariablen:

```bash
CATALOG_HOST=127.0.0.1 CATALOG_PORT=8080 dart run bin/catalog_service.dart
```

## Wichtige Endpunkte

- `GET /`
- `GET /health`
- `GET /stats`
- `GET /books`
- `GET /books?available=true`
- `GET /books?search=clean`
- `GET /books/1`
- `POST /books`
- `PATCH /books/1`
- `DELETE /books/1`
- `POST /books/1/borrow`
- `POST /books/1/return`

## Beispiel-Requests

Neues Buch anlegen:

```bash
curl -X POST http://127.0.0.1:8080/books \
  -H 'Content-Type: application/json' \
  -d '{"title":"Building Microservices","author":"Sam Newman","year":2021}'
```

Buch ausleihen:

```bash
curl -X POST http://127.0.0.1:8080/books/1/borrow \
  -H 'Content-Type: application/json' \
  -d '{"borrower":"Mia Sommer","loanDays":10}'
```

Buch teilweise aendern:

```bash
curl -X PATCH http://127.0.0.1:8080/books/1 \
  -H 'Content-Type: application/json' \
  -d '{"title":"Clean Code im Unterricht"}'
```

## Tests und Analyse

```bash
dart analyze
dart test
```

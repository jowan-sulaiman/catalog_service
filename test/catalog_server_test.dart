import 'dart:convert';
import 'dart:io';

import 'package:catalog_service/catalog_service.dart';
import 'package:test/test.dart';

void main() {
  group('CatalogServer', () {
    late CatalogServer server;
    late Uri baseUri;

    setUp(() async {
      server = CatalogServer(
        config: const ServerConfig(
          host: '127.0.0.1',
          port: 0,
          logRequests: false,
        ),
        service: CatalogService(
          clock: () => DateTime.utc(2026, 3, 22, 12, 0),
          seedBooks: {
            1: const Book(
              id: 1,
              title: 'Clean Code',
              author: 'Robert C. Martin',
              year: 2008,
              available: true,
            ),
            2: const Book(
              id: 2,
              title: 'Refactoring',
              author: 'Martin Fowler',
              year: 1999,
              available: true,
            ),
          },
        ),
      );

      await server.start();
      baseUri = server.baseUri;
    });

    tearDown(() async {
      await server.close(force: true);
    });

    test('liefert Health-Informationen', () async {
      final response = await _sendJsonRequest(
        method: 'GET',
        uri: baseUri.resolve('/health'),
      );

      expect(response.statusCode, equals(HttpStatus.ok));
      expect(response.jsonBody['status'], equals('ok'));
      expect(response.jsonBody['service'], equals('catalog-service'));
    });

    test('erstellt ein Buch und filtert anschliessend den Katalog', () async {
      final created = await _sendJsonRequest(
        method: 'POST',
        uri: baseUri.resolve('/books'),
        body: {
          'title': 'Building Microservices',
          'author': 'Sam Newman',
          'year': 2021,
        },
      );

      final filtered = await _sendJsonRequest(
        method: 'GET',
        uri: baseUri.resolve('/books?available=true&search=micro'),
      );

      expect(created.statusCode, equals(HttpStatus.created));
      expect(
        created.jsonBody['item']['title'],
        equals('Building Microservices'),
      );
      expect(filtered.statusCode, equals(HttpStatus.ok));
      expect(filtered.jsonBody['count'], equals(1));
      expect(filtered.jsonBody['items'][0]['author'], equals('Sam Newman'));
    });

    test('patcht ein vorhandenes Buch', () async {
      final response = await _sendJsonRequest(
        method: 'PATCH',
        uri: baseUri.resolve('/books/1'),
        body: {'title': 'Clean Code im Unterricht'},
      );

      expect(response.statusCode, equals(HttpStatus.ok));
      expect(
        response.jsonBody['item']['title'],
        equals('Clean Code im Unterricht'),
      );
    });

    test(
      'leiht ein Buch aus und liefert die Leihinformationen zurueck',
      () async {
        final response = await _sendJsonRequest(
          method: 'POST',
          uri: baseUri.resolve('/books/1/borrow'),
          body: {'borrower': 'Mia Sommer', 'loanDays': 10},
        );

        expect(response.statusCode, equals(HttpStatus.ok));
        expect(response.jsonBody['item']['available'], isFalse);
        expect(response.jsonBody['item']['borrower'], equals('Mia Sommer'));
        expect(
          response.jsonBody['item']['dueDate'],
          equals('2026-04-01T12:00:00.000Z'),
        );
      },
    );

    test('loescht ein Buch aus dem Katalog', () async {
      final deleteResponse = await _sendJsonRequest(
        method: 'DELETE',
        uri: baseUri.resolve('/books/2'),
      );
      final getResponse = await _sendJsonRequest(
        method: 'GET',
        uri: baseUri.resolve('/books/2'),
      );

      expect(deleteResponse.statusCode, equals(HttpStatus.ok));
      expect(deleteResponse.jsonBody['item']['id'], equals(2));
      expect(getResponse.statusCode, equals(HttpStatus.notFound));
      expect(getResponse.jsonBody['error'], equals('book_not_found'));
    });

    test('liefert eine Statistik ueber den Katalog', () async {
      await _sendJsonRequest(
        method: 'POST',
        uri: baseUri.resolve('/books/1/borrow'),
      );

      final response = await _sendJsonRequest(
        method: 'GET',
        uri: baseUri.resolve('/stats'),
      );

      expect(response.statusCode, equals(HttpStatus.ok));
      expect(response.jsonBody['stats']['totalBooks'], equals(2));
      expect(response.jsonBody['stats']['borrowedBooks'], equals(1));
      expect(response.jsonBody['stats']['availableBooks'], equals(1));
    });
  });
}

class _JsonResponse {
  const _JsonResponse({required this.statusCode, required this.jsonBody});

  final int statusCode;
  final Map<String, dynamic> jsonBody;
}

Future<_JsonResponse> _sendJsonRequest({
  required String method,
  required Uri uri,
  Map<String, dynamic>? body,
}) async {
  final client = HttpClient();

  try {
    final request = await client.openUrl(method, uri);
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
    }

    final response = await request.close();
    final rawBody = await utf8.decoder.bind(response).join();
    final decoded = rawBody.isEmpty
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(jsonDecode(rawBody) as Map);

    return _JsonResponse(statusCode: response.statusCode, jsonBody: decoded);
  } finally {
    client.close(force: true);
  }
}

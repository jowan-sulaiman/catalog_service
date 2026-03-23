import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'api_exception.dart';
import 'catalog_service.dart';
import 'server_config.dart';

/// HTTP-Adapter fuer den Catalog Service.
/// Die Klasse kapselt Routing, Request-Parsing, JSON-Antworten und Start/Stopp
/// des Servers. Fuer uns ist hier sehr gut sichtbar, wie aus
/// Fachoperationen tatsaechliche HTTP-Endpunkte werden.
class CatalogServer {
  CatalogServer({
    CatalogService? service,
    ServerConfig config = const ServerConfig(),
  }) : service = service ?? CatalogService(),
       config = config;

  final CatalogService service;
  final ServerConfig config;

  HttpServer? _server;
  StreamSubscription<HttpRequest>? _subscription;

  Uri get baseUri {
    final server = _server;
    if (server == null) {
      throw StateError('Der Server wurde noch nicht gestartet.');
    }

    return Uri(scheme: 'http', host: server.address.address, port: server.port);
  }

  /// Bindet den HTTP-Server und beginnt eingehende Requests zu verarbeiten.
  Future<CatalogServer> start() async {
    if (_server != null) {
      return this;
    }

    final server = await HttpServer.bind(config.host, config.port);
    _server = server;

    _subscription = server.listen((request) {
      // Jeder Request wird asynchron verarbeitet, damit der Server nicht durch
      // einen einzelnen langsamen Aufruf blockiert wird.
      unawaited(_handleRequestWithLogging(request));
    });

    return this;
  }

  /// Wartet auf ein Betriebssystem-Signal und faehrt den Server sauber herunter.
  Future<void> waitForShutdownSignal() async {
    await Future.any([
      ProcessSignal.sigint.watch().first,
      ProcessSignal.sigterm.watch().first,
    ]);

    await close();
  }

  Future<void> close({bool force = false}) async {
    final server = _server;
    if (server == null) {
      return;
    }

    await server.close(force: force);
    await _subscription?.cancel();

    _subscription = null;
    _server = null;
  }

  Future<void> _handleRequestWithLogging(HttpRequest request) async {
    final stopwatch = Stopwatch()..start();
    await handleRequest(request);
    stopwatch.stop();

    if (config.logRequests) {
      stdout.writeln(
        '${request.method} ${request.uri.path}${request.uri.hasQuery ? '?${request.uri.query}' : ''} '
        '-> ${request.response.statusCode} (${stopwatch.elapsedMilliseconds} ms)',
      );
    }
  }

  /// Zentrale Routing-Methode.
  /// Fuer kleine Lehrprojekte ist ein expliziter Dispatcher oft didaktisch
  /// hilfreicher als ein komplettes Framework, weil Methoden, Pfade und
  /// Antworten direkt nebeneinander stehen.
  Future<void> handleRequest(HttpRequest request) async {
    final segments = request.uri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);

    try {
      if (request.method == 'OPTIONS') {
        return _writeNoContent(request.response);
      }

      if (segments.isEmpty) {
        if (request.method != 'GET') {
          throw ApiException.methodNotAllowed(
            'Die Root-Route unterstuetzt nur GET',
          );
        }

        return _writeJson(request.response, HttpStatus.ok, {
          'service': 'catalog-service',
          'description': 'Dart-Microservice fuer eine digitale Schulbibliothek',
          'endpoints': [
            'GET /',
            'GET /health',
            'GET /stats',
            'GET /books',
            'GET /books/:id',
            'POST /books',
            'PATCH /books/:id',
            'DELETE /books/:id',
            'POST /books/:id/borrow',
            'POST /books/:id/return',
          ],
        });
      }

      if (segments.length == 1 && segments[0] == 'health') {
        if (request.method != 'GET') {
          throw ApiException.methodNotAllowed(
            'Die Route /health unterstuetzt nur GET',
          );
        }

        return _writeJson(request.response, HttpStatus.ok, {
          'status': 'ok',
          'service': 'catalog-service',
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        });
      }

      if (segments.length == 1 && segments[0] == 'stats') {
        if (request.method != 'GET') {
          throw ApiException.methodNotAllowed(
            'Die Route /stats unterstuetzt nur GET',
          );
        }

        return _writeJson(request.response, HttpStatus.ok, {
          'stats': service.statistics(),
        });
      }

      if (segments.length == 1 && segments[0] == 'books') {
        if (request.method == 'GET') {
          return _handleBookList(request);
        }

        if (request.method == 'POST') {
          final payload = await _readRequiredJsonBody(request);
          final created = service.createBook(payload);

          return _writeJson(request.response, HttpStatus.created, {
            'item': created.toJson(),
          });
        }

        throw ApiException.methodNotAllowed(
          'Die Route /books unterstuetzt nur GET und POST',
        );
      }

      if (segments.length == 2 && segments[0] == 'books') {
        final id = _parseBookId(segments[1]);

        if (request.method == 'GET') {
          final book = service.findBook(id);

          return _writeJson(request.response, HttpStatus.ok, {
            'item': book.toJson(),
          });
        }

        if (request.method == 'PATCH') {
          final payload = await _readRequiredJsonBody(request);
          final updated = service.updateBook(id, payload);

          return _writeJson(request.response, HttpStatus.ok, {
            'item': updated.toJson(),
          });
        }

        if (request.method == 'DELETE') {
          final deleted = service.deleteBook(id);

          return _writeJson(request.response, HttpStatus.ok, {
            'item': deleted.toJson(),
          });
        }

        throw ApiException.methodNotAllowed(
          'Die Route /books/:id unterstuetzt GET, PATCH und DELETE',
        );
      }

      if (segments.length == 3 &&
          segments[0] == 'books' &&
          segments[2] == 'borrow') {
        if (request.method != 'POST') {
          throw ApiException.methodNotAllowed(
            'Die Route /books/:id/borrow unterstuetzt nur POST',
          );
        }

        final id = _parseBookId(segments[1]);
        final payload = await _readOptionalJsonBody(request);
        final updated = service.borrowBook(id, payload: payload);

        return _writeJson(request.response, HttpStatus.ok, {
          'item': updated.toJson(),
        });
      }

      if (segments.length == 3 &&
          segments[0] == 'books' &&
          segments[2] == 'return') {
        if (request.method != 'POST') {
          throw ApiException.methodNotAllowed(
            'Die Route /books/:id/return unterstuetzt nur POST',
          );
        }

        final id = _parseBookId(segments[1]);
        final updated = service.returnBook(id);

        return _writeJson(request.response, HttpStatus.ok, {
          'item': updated.toJson(),
        });
      }

      throw ApiException.notFound(
        'Route nicht gefunden',
        code: 'route_not_found',
      );
    } on ApiException catch (error) {
      return _writeJson(request.response, error.statusCode, error.toJson());
    } catch (error, stackTrace) {
      stderr.writeln(
        'Unerwarteter Fehler bei ${request.method} ${request.uri}: '
        '$error\n$stackTrace',
      );

      return _writeJson(request.response, HttpStatus.internalServerError, {
        'error': 'internal_error',
        'message': 'Unerwarteter Serverfehler',
      });
    }
  }

  Future<void> _handleBookList(HttpRequest request) async {
    final available = _parseOptionalBool(
      request.uri.queryParameters['available'],
      key: 'available',
    );
    final search = _normalizeQueryValue(request.uri.queryParameters['search']);
    final author = _normalizeQueryValue(request.uri.queryParameters['author']);

    final books = service.listBooks(
      available: available,
      search: search,
      author: author,
    );

    return _writeJson(request.response, HttpStatus.ok, {
      'count': books.length,
      'filters': {'available': available, 'search': search, 'author': author},
      'items': books.map((book) => book.toJson()).toList(),
    });
  }

  int _parseBookId(String rawSegment) {
    final id = int.tryParse(rawSegment);
    if (id == null || id <= 0) {
      throw ApiException.badRequest(
        'Buch-ID muss eine positive ganze Zahl sein',
        code: 'invalid_book_id',
      );
    }

    return id;
  }

  bool? _parseOptionalBool(String? rawValue, {required String key}) {
    final normalized = _normalizeQueryValue(rawValue)?.toLowerCase();
    if (normalized == null) {
      return null;
    }

    switch (normalized) {
      case 'true':
      case '1':
      case 'yes':
      case 'ja':
        return true;
      case 'false':
      case '0':
      case 'no':
      case 'nein':
        return false;
      default:
        throw ApiException.badRequest(
          'Query-Parameter "$key" muss true oder false sein',
          code: 'invalid_$key',
        );
    }
  }

  String? _normalizeQueryValue(String? rawValue) {
    final trimmed = rawValue?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    return trimmed;
  }

  Future<Map<String, dynamic>> _readRequiredJsonBody(
    HttpRequest request,
  ) async {
    final payload = await _readOptionalJsonBody(request);
    if (payload.isEmpty) {
      throw ApiException.badRequest('Leerer JSON-Body', code: 'empty_body');
    }

    return payload;
  }

  Future<Map<String, dynamic>> _readOptionalJsonBody(
    HttpRequest request,
  ) async {
    final body = await utf8.decoder.bind(request).join();
    if (body.trim().isEmpty) {
      return {};
    }

    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw ApiException.badRequest(
        'JSON-Objekt erwartet',
        code: 'invalid_json_body',
      );
    }

    return Map<String, dynamic>.from(decoded);
  }

  Future<void> _writeNoContent(HttpResponse response) async {
    _applyDefaultHeaders(response);
    response.statusCode = HttpStatus.noContent;
    await response.close();
  }

  Future<void> _writeJson(
    HttpResponse response,
    int statusCode,
    Object data,
  ) async {
    _applyDefaultHeaders(response);
    response.statusCode = statusCode;
    response.write(jsonEncode(data));
    await response.close();
  }

  void _applyDefaultHeaders(HttpResponse response) {
    response.headers.set(
      HttpHeaders.contentTypeHeader,
      'application/json; charset=utf-8',
    );
    response.headers.set(HttpHeaders.accessControlAllowOriginHeader, '*');
    response.headers.set(
      HttpHeaders.accessControlAllowMethodsHeader,
      'GET, POST, PATCH, DELETE, OPTIONS',
    );
    response.headers.set(
      HttpHeaders.accessControlAllowHeadersHeader,
      'content-type',
    );
  }
}

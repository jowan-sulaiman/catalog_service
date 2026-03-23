import 'dart:io';

/// Fehlerklasse fuer fachliche oder technische API-Probleme.
/// Die Klasse entkoppelt Service-Schicht und HTTP-Schicht nicht komplett,
/// macht fuer ein Lehrprojekt aber sehr klar sichtbar, wie ein fachlicher
/// Fehler auf einen HTTP-Statuscode abgebildet wird.
class ApiException implements Exception {
  ApiException(this.statusCode, this.code, this.message);

  final int statusCode;
  final String code;
  final String message;

  factory ApiException.badRequest(
    String message, {
    String code = 'bad_request',
  }) {
    return ApiException(HttpStatus.badRequest, code, message);
  }

  factory ApiException.notFound(String message, {String code = 'not_found'}) {
    return ApiException(HttpStatus.notFound, code, message);
  }

  factory ApiException.conflict(String message, {String code = 'conflict'}) {
    return ApiException(HttpStatus.conflict, code, message);
  }

  factory ApiException.methodNotAllowed(
    String message, {
    String code = 'method_not_allowed',
  }) {
    return ApiException(HttpStatus.methodNotAllowed, code, message);
  }

  Map<String, dynamic> toJson() {
    return {'error': code, 'message': message};
  }

  @override
  String toString() {
    return 'ApiException(statusCode: $statusCode, code: $code, message: $message)';
  }
}

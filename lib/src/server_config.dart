import 'dart:io';

/// Konfiguration fuer den HTTP-Server.
/// Die Werte koennen direkt im Code gesetzt oder ueber Umgebungsvariablen
/// geladen werden. Das ist fuer Unterricht und Deployment gleichermaassen
/// praktisch.
class ServerConfig {
  const ServerConfig({
    this.host = '127.0.0.1',
    this.port = 8080,
    this.logRequests = true,
  });

  final String host;
  final int port;
  final bool logRequests;

  factory ServerConfig.fromEnvironment() {
    final environment = Platform.environment;

    return ServerConfig(
      host: _readHost(environment['CATALOG_HOST']),
      port: _readPort(environment['CATALOG_PORT']),
      logRequests: _readLogFlag(environment['CATALOG_LOG_REQUESTS']),
    );
  }
}

String _readHost(String? rawHost) {
  final trimmed = rawHost?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return '127.0.0.1';
  }

  return trimmed;
}

int _readPort(String? rawPort) {
  final port = int.tryParse(rawPort ?? '');
  if (port == null || port < 0 || port > 65535) {
    return 8080;
  }

  return port;
}

bool _readLogFlag(String? rawValue) {
  final normalized = rawValue?.trim().toLowerCase();
  if (normalized == 'false' || normalized == '0' || normalized == 'no') {
    return false;
  }

  return true;
}

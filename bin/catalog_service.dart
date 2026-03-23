import 'package:catalog_service/catalog_service.dart';

Future<void> main() async {
  final server = await CatalogServer(
    config: ServerConfig.fromEnvironment(),
  ).start();

  // Die Ausgaben sind bewusst knapp gehalten, damit wir sofort sehen,
  // unter welcher Adresse der Dienst erreichbar ist.
  print('Catalog Service laeuft auf ${server.baseUri}');
  print('Health-Check: ${server.baseUri.resolve('/health')}');
  print('Mit Strg+C beenden');

  await server.waitForShutdownSignal();
}

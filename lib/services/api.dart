import '../utils/config.dart';
import 'apps_script_client.dart';

/// Instância única do cliente do backend, usada por todas as telas.
final AppsScriptClient api = AppsScriptClient(AppConfig.backendUrl);

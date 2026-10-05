/// Configuração injetada no build (não fica no código nem no repositório).
///
/// Local:  flutter run -d chrome --dart-define-from-file=env.json
/// Deploy: o workflow do GitHub passa BACKEND_URL a partir de um secret.
class AppConfig {
  /// Endereço /exec do Web App do Apps Script.
  static const String backendUrl = String.fromEnvironment('BACKEND_URL');

  static bool get configured => backendUrl.isNotEmpty;
}

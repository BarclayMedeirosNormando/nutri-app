import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Erro de API com um código estável (ex.: 'invalid_credentials', 'unauthorized',
/// 'network'). A tradução para o usuário fica em friendlyError().
class ApiException implements Exception {
  final String code;
  const ApiException(this.code);

  @override
  String toString() => 'ApiException($code)';
}

/// Cliente único do backend (Apps Script).
///
/// O JSON vai como text/plain para evitar o preflight de CORS, que o
/// Apps Script não responde.
class AppsScriptClient {
  AppsScriptClient(this.baseUrl, {http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _http;

  /// Token da sessão; enviado automaticamente em todas as chamadas.
  String? token;

  Future<dynamic> call(
    String action, [
    Map<String, dynamic>? data,
  ]) async {
    if (baseUrl.isEmpty) throw const ApiException('not_configured_app');

    final body = <String, dynamic>{
      'action': action,
      if (token != null) 'token': token,
      ...?data,
    };

    http.Response resp;
    try {
      resp = await _http
          .post(
            Uri.parse(baseUrl),
            headers: const {'Content-Type': 'text/plain'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw const ApiException('timeout');
    } catch (_) {
      throw const ApiException('network');
    }

    Map<String, dynamic> json;
    try {
      json = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw const ApiException('bad_response');
    }

    if (json['status'] != 'success') {
      throw ApiException((json['code'] as String?) ?? 'server_error');
    }
    return json['data'];
  }
}

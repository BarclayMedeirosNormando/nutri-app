import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

/// Detecta uma nova publicação do app comparando os cabeçalhos do main.dart.js
/// (etag, last-modified, content-length) com os da primeira consulta desta aba.
class UpdateChecker {
  String? _baseline;

  Future<bool> hasUpdate() async {
    try {
      final url = Uri.parse(web.document.baseURI).resolve('main.dart.js');
      final r = await http
          .head(url, headers: const {'Cache-Control': 'no-cache'})
          .timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return false;

      final sig = ['etag', 'last-modified', 'content-length']
          .map((h) => r.headers[h] ?? '')
          .join('|');
      if (sig == '||') return false; // servidor sem cabeçalhos úteis

      if (_baseline == null) {
        _baseline = sig; // primeira consulta: define a versão em uso
        return false;
      }
      return sig != _baseline;
    } catch (_) {
      return false; // sem rede ou erro: tenta de novo na próxima
    }
  }

  void reload() => web.window.location.reload();
}

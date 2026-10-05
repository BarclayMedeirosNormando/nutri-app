import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Entrega [bytes] ao navegador como download com o nome [nome].
void baixarArquivo(Uint8List bytes, String nome, String mime) {
  final blob = web.Blob(
    <JSAny>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: mime),
  );
  final url = web.URL.createObjectURL(blob);
  final a = web.document.createElement('a') as web.HTMLAnchorElement;
  a.href = url;
  a.download = nome;
  web.document.body!.append(a);
  a.click();
  a.remove();
  web.URL.revokeObjectURL(url);
}

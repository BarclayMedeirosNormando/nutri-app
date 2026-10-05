import 'dart:typed_data';

/// Fora do navegador não há como baixar o arquivo.
void baixarArquivo(Uint8List bytes, String nome, String mime) {
  throw UnsupportedError('Download disponível apenas no navegador.');
}

import 'package:idb_shim/idb.dart';

import 'idb_factory_stub.dart' if (dart.library.js_interop) 'idb_factory_web.dart';

/// Armazenamento local no aparelho (IndexedDB), chave -> texto.
///
/// REGRA DO PROJETO: guardar aqui apenas dados públicos (tabela de alimentos).
/// Dados de pacientes ficam só em memória durante a sessão.
class LocalStore {
  const LocalStore._();

  static const _banco = 'nutriapp';
  static const _loja = 'cache';
  static Database? _db;

  static Future<Database> _abrir() async {
    return _db ??= await getIdbFactory().open(
      _banco,
      version: 1,
      onUpgradeNeeded: (e) {
        e.database.createObjectStore(_loja);
      },
    );
  }

  static Future<void> salvar(String chave, String valor) async {
    final db = await _abrir();
    final tx = db.transaction(_loja, idbModeReadWrite);
    await tx.objectStore(_loja).put(valor, chave);
    await tx.completed;
  }

  static Future<String?> ler(String chave) async {
    final db = await _abrir();
    final tx = db.transaction(_loja, idbModeReadOnly);
    final v = await tx.objectStore(_loja).getObject(chave);
    await tx.completed;
    return v is String ? v : null;
  }
}

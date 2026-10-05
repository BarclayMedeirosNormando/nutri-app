import 'dart:async';
import 'dart:convert';

import '../models/alimento.dart';
import 'api.dart';
import 'local_store.dart';

/// Guarda a tabela de alimentos em memória (cálculo rápido, sem chamar o
/// Apps Script a cada conta) e no aparelho (abre instantâneo na próxima vez).
class AlimentoRepositorio {
  AlimentoRepositorio._();
  static final AlimentoRepositorio instancia = AlimentoRepositorio._();

  static const _chave = 'alimentos_v1';
  static const _validade = Duration(hours: 24);

  List<Alimento> _lista = const [];
  DateTime? atualizadoEm;
  bool _atualizando = false;

  List<Alimento> get lista => _lista;

  /// Devolve a tabela. Usa memória, depois o cache do aparelho; só vai ao
  /// servidor se não houver cache (ou se [forcar]). Cache velho (mais de 24 h)
  /// é renovado em segundo plano. Se [forcar] falhar, a exceção sobe, mas o
  /// que já estava carregado continua disponível.
  Future<List<Alimento>> carregar({bool forcar = false}) async {
    if (_lista.isNotEmpty && !forcar) return _lista;

    if (!forcar && await _lerCache()) {
      final idade = DateTime.now().difference(atualizadoEm!);
      if (idade > _validade) unawaited(_atualizarEmSegundoPlano());
      return _lista;
    }

    await _buscarServidor();
    return _lista;
  }

  Future<bool> _lerCache() async {
    try {
      final s = await LocalStore.ler(_chave);
      if (s == null) return false;
      final m = jsonDecode(s) as Map<String, dynamic>;
      final itens = (m['alimentos'] as List)
          .map((e) => Alimento.fromJson(e as Map<String, dynamic>))
          .toList();
      if (itens.isEmpty) return false;
      _lista = itens;
      atualizadoEm = DateTime.fromMillisecondsSinceEpoch(m['em'] as int);
      return true;
    } catch (_) {
      return false; // cache ilegível: ignora e busca no servidor
    }
  }

  Future<void> _buscarServidor() async {
    final data = await api.call('listAlimentos') as Map<String, dynamic>;
    final itens = (data['alimentos'] as List)
        .map((e) => Alimento.fromJson(e as Map<String, dynamic>))
        .toList();
    _lista = itens;
    atualizadoEm = DateTime.now();
    try {
      await LocalStore.salvar(
        _chave,
        jsonEncode({
          'em': atualizadoEm!.millisecondsSinceEpoch,
          'alimentos': itens.map((a) => a.toJson()).toList(),
        }),
      );
    } catch (_) {
      // sem armazenamento local: segue só com a memória
    }
  }

  Future<void> _atualizarEmSegundoPlano() async {
    if (_atualizando) return;
    _atualizando = true;
    try {
      await _buscarServidor();
    } catch (_) {
      // mantém o que já temos
    } finally {
      _atualizando = false;
    }
  }
}

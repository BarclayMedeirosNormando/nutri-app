import '../models/plano.dart';
import 'api.dart';

class PlanoService {
  const PlanoService._();

  /// Planos de um paciente, sem refeições (só o resumo).
  static Future<List<Plano>> listar(String pacienteId) async {
    final data = await api.call('listPlanos', {'paciente_id': pacienteId})
        as Map<String, dynamic>;
    return (data['planos'] as List)
        .map((e) => Plano.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Plano completo, com refeições e itens.
  static Future<Plano> obter(String id) async {
    final data =
        await api.call('getPlano', {'id': id}) as Map<String, dynamic>;
    return Plano.fromJson(data['plano'] as Map<String, dynamic>);
  }

  /// Cria (id vazio) ou atualiza o plano inteiro de uma vez.
  static Future<Plano> salvar(Plano p) async {
    final data = await api.call('savePlano', {'plano': p.toJson()})
        as Map<String, dynamic>;
    return Plano.fromJson(data['plano'] as Map<String, dynamic>);
  }

  /// Só planos em rascunho podem ser apagados.
  static Future<void> apagar(String id) async {
    await api.call('deletePlano', {'id': id});
  }
}

class MedidaService {
  const MedidaService._();

  static Future<List<MedidaCaseira>> listar() async {
    final data = await api.call('listMedidasCaseiras') as Map<String, dynamic>;
    return (data['medidas'] as List)
        .map((e) => MedidaCaseira.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Cria (id vazio) ou atualiza uma medida caseira.
  static Future<MedidaCaseira> salvar(MedidaCaseira m) async {
    final data = await api.call('saveMedidaCaseira', {'medida': m.toJson()})
        as Map<String, dynamic>;
    return MedidaCaseira.fromJson(data['medida'] as Map<String, dynamic>);
  }

  static Future<void> apagar(String id) async {
    await api.call('deleteMedidaCaseira', {'id': id});
  }
}

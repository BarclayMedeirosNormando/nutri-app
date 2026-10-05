import '../models/paciente.dart';
import 'api.dart';

class PacienteService {
  const PacienteService._();

  static Future<List<Paciente>> listar({bool incluirArquivados = false}) async {
    final data = await api.call(
      'listPacientes',
      {'incluirArquivados': incluirArquivados},
    ) as Map<String, dynamic>;
    return (data['pacientes'] as List)
        .map((e) => Paciente.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Cria (id vazio) ou atualiza. [consentimento] true registra o consentimento LGPD.
  static Future<Paciente> salvar(
    Paciente p, {
    bool consentimento = false,
  }) async {
    final data = await api.call('savePaciente', {
      'paciente': p.toJson(),
      'consentimento': consentimento,
    }) as Map<String, dynamic>;
    return Paciente.fromJson(data['paciente'] as Map<String, dynamic>);
  }

  /// [arquivar] true arquiva; false reativa.
  static Future<Paciente> arquivar(String id, bool arquivar) async {
    final data = await api.call(
      'archivePaciente',
      {'id': id, 'arquivar': arquivar},
    ) as Map<String, dynamic>;
    return Paciente.fromJson(data['paciente'] as Map<String, dynamic>);
  }
}

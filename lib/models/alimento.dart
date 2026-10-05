import '../utils/texto.dart';

/// Alimento com valores por 100 g. Valor nulo = sem dado na fonte (conta como 0 no cálculo).
class Alimento {
  Alimento({
    required this.id,
    required this.origem,
    required this.nome,
    required this.categoria,
    this.energiaKcal,
    this.proteinaG,
    this.lipidiosG,
    this.carboidratoG,
    this.fibraG,
    this.sodioMg,
  });

  final String id;

  /// 'TACO', 'OFF' (Open Food Facts) ou 'PROPRIO'.
  final String origem;
  final String nome;
  final String categoria;
  final double? energiaKcal;
  final double? proteinaG;
  final double? lipidiosG;
  final double? carboidratoG;
  final double? fibraG;
  final double? sodioMg;

  /// Nome sem acento e em minúsculas, para busca.
  late final String nomeNormalizado = semAcento(nome);

  /// Falta algum macronutriente na fonte.
  bool get incompleto =>
      energiaKcal == null ||
      proteinaG == null ||
      lipidiosG == null ||
      carboidratoG == null;

  factory Alimento.fromJson(Map<String, dynamic> j) {
    double? d(String k) {
      final v = j[k];
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString().replaceAll(',', '.'));
    }

    String s(String k) => (j[k] ?? '').toString();
    return Alimento(
      id: s('id'),
      origem: s('origem'),
      nome: s('nome'),
      categoria: s('categoria'),
      energiaKcal: d('energia_kcal'),
      proteinaG: d('proteina_g'),
      lipidiosG: d('lipidios_g'),
      carboidratoG: d('carboidrato_g'),
      fibraG: d('fibra_g'),
      sodioMg: d('sodio_mg'),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'origem': origem,
        'nome': nome,
        'categoria': categoria,
        'energia_kcal': energiaKcal,
        'proteina_g': proteinaG,
        'lipidios_g': lipidiosG,
        'carboidrato_g': carboidratoG,
        'fibra_g': fibraG,
        'sodio_mg': sodioMg,
      };
}

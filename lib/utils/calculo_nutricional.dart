import '../models/alimento.dart';
import '../models/plano.dart';

/// Totais nutricionais. Valores ausentes na tabela de alimentos contam como zero;
/// [semDados] conta os itens cujo alimento não foi achado ou tem dados incompletos.
class Totais {
  const Totais({
    this.kcal = 0,
    this.proteina = 0,
    this.lipidios = 0,
    this.carboidrato = 0,
    this.fibra = 0,
    this.sodio = 0,
    this.semDados = 0,
  });

  static const zero = Totais();

  final double kcal;
  final double proteina;
  final double lipidios;
  final double carboidrato;
  final double fibra;
  final double sodio;
  final int semDados;

  Totais operator +(Totais o) => Totais(
        kcal: kcal + o.kcal,
        proteina: proteina + o.proteina,
        lipidios: lipidios + o.lipidios,
        carboidrato: carboidrato + o.carboidrato,
        fibra: fibra + o.fibra,
        sodio: sodio + o.sodio,
        semDados: semDados + o.semDados,
      );

  /// Calorias dos macros (4/4/9 kcal por g), base dos percentuais.
  double get _kcalMacros => proteina * 4 + carboidrato * 4 + lipidios * 9;

  double get pctProteina => _kcalMacros == 0 ? 0 : proteina * 4 / _kcalMacros * 100;
  double get pctCarboidrato =>
      _kcalMacros == 0 ? 0 : carboidrato * 4 / _kcalMacros * 100;
  double get pctLipidios => _kcalMacros == 0 ? 0 : lipidios * 9 / _kcalMacros * 100;
}

Map<String, Alimento> indexarAlimentos(Iterable<Alimento> lista) =>
    {for (final a in lista) a.id: a};

/// Totais de um item (valores da tabela são por 100 g).
Totais totaisItem(ItemRefeicao item, Alimento? a) {
  if (a == null) return const Totais(semDados: 1);
  final f = item.gramas / 100;
  return Totais(
    kcal: (a.energiaKcal ?? 0) * f,
    proteina: (a.proteinaG ?? 0) * f,
    lipidios: (a.lipidiosG ?? 0) * f,
    carboidrato: (a.carboidratoG ?? 0) * f,
    fibra: (a.fibraG ?? 0) * f,
    sodio: (a.sodioMg ?? 0) * f,
    semDados: a.incompleto ? 1 : 0,
  );
}

Totais totaisRefeicao(Refeicao r, Map<String, Alimento> alimentos) {
  var t = Totais.zero;
  for (final it in r.itens) {
    t = t + totaisItem(it, alimentos[it.alimentoId]);
  }
  return t;
}

Totais totaisPlano(Plano p, Map<String, Alimento> alimentos) {
  var t = Totais.zero;
  for (final r in p.refeicoes) {
    t = t + totaisRefeicao(r, alimentos);
  }
  return t;
}

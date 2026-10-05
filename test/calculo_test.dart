import 'package:flutter_test/flutter_test.dart';

import 'package:nutri_app/models/alimento.dart';
import 'package:nutri_app/models/plano.dart';
import 'package:nutri_app/utils/calculo_nutricional.dart';

Alimento _arroz() => Alimento(
      id: 'A1',
      origem: 'TACO',
      nome: 'Arroz, cozido',
      categoria: 'Cereais',
      energiaKcal: 128,
      proteinaG: 2.5,
      lipidiosG: 0.2,
      carboidratoG: 28,
      fibraG: 1.6,
      sodioMg: 1,
    );

Alimento _incompleto() => Alimento(
      id: 'A2',
      origem: 'TACO',
      nome: 'Alimento incompleto (sem carboidrato)',
      categoria: 'Outros',
      energiaKcal: 100,
      proteinaG: 10,
      lipidiosG: 5,
    );

void main() {
  group('totaisItem', () {
    test('150 g de arroz', () {
      final t = totaisItem(
        ItemRefeicao(alimentoId: 'A1', quantidade: 150, gramas: 150),
        _arroz(),
      );
      expect(t.kcal, closeTo(192, 0.001));
      expect(t.proteina, closeTo(3.75, 0.001));
      expect(t.carboidrato, closeTo(42, 0.001));
      expect(t.semDados, 0);
    });

    test('valor ausente conta como zero e sinaliza dados incompletos', () {
      final t = totaisItem(
        ItemRefeicao(alimentoId: 'A2', quantidade: 200, gramas: 200),
        _incompleto(),
      );
      expect(t.kcal, closeTo(200, 0.001));
      expect(t.fibra, 0);
      expect(t.sodio, 0);
      expect(t.semDados, 1);
    });

    test('alimento não encontrado não soma e sinaliza', () {
      final t = totaisItem(ItemRefeicao(alimentoId: 'X'), null);
      expect(t.kcal, 0);
      expect(t.semDados, 1);
    });
  });

  group('totaisPlano', () {
    test('soma as refeições', () {
      final plano = Plano(refeicoes: [
        Refeicao(nome: 'Café', itens: [
          ItemRefeicao(alimentoId: 'A1', quantidade: 100, gramas: 100),
        ]),
        Refeicao(nome: 'Almoço', itens: [
          ItemRefeicao(alimentoId: 'A1', quantidade: 200, gramas: 200),
          ItemRefeicao(alimentoId: 'A2', quantidade: 100, gramas: 100),
        ]),
      ]);
      final mapa = indexarAlimentos([_arroz(), _incompleto()]);
      final t = totaisPlano(plano, mapa);
      expect(t.kcal, closeTo(128 + 256 + 100, 0.001));
      expect(totaisRefeicao(plano.refeicoes[0], mapa).kcal, closeTo(128, 0.001));
      expect(t.semDados, 1);
    });

    test('percentuais dos macros somam 100', () {
      const t = Totais(proteina: 25, carboidrato: 50, lipidios: 10);
      expect(t.pctProteina + t.pctCarboidrato + t.pctLipidios, closeTo(100, 0.001));
      expect(const Totais().pctProteina, 0);
    });
  });

  group('ItemRefeicao.recalcularGramas', () {
    const colher = MedidaCaseira(
        id: 'M1', alimentoId: 'A1', descricao: 'Colher de sopa', gramas: 25);

    test('com medida caseira', () {
      final it = ItemRefeicao(alimentoId: 'A1', quantidade: 3);
      it.recalcularGramas(colher);
      expect(it.gramas, 75);
    });

    test('sem medida, a quantidade já está em gramas', () {
      final it = ItemRefeicao(alimentoId: 'A1', quantidade: 200);
      it.recalcularGramas(null);
      expect(it.gramas, 200);
    });

    test('arredonda em 1 casa decimal como o servidor', () {
      const m = MedidaCaseira(
          id: 'M2', alimentoId: 'A1', descricao: 'Fatia', gramas: 33.33);
      final it = ItemRefeicao(alimentoId: 'A1', quantidade: 3);
      it.recalcularGramas(m);
      expect(it.gramas, 100.0);
    });
  });

  group('Plano JSON', () {
    test('lê a resposta do servidor (números como texto ou número)', () {
      final p = Plano.fromJson({
        'id': 'P1',
        'paciente_id': 'X',
        'nome': 'Plano',
        'meta_kcal': '1800',
        'status': 'ativo',
        'refeicoes': [
          {
            'id': 'R1',
            'nome': 'Café',
            'horario': '07:30',
            'itens': [
              {
                'id': 'I1',
                'alimento_id': 'A1',
                'medida_caseira_id': '',
                'quantidade': '200,5',
                'gramas': 200.5,
              }
            ],
          }
        ],
      });
      expect(p.metaKcal, 1800);
      expect(p.refeicoes.single.itens.single.quantidade, 200.5);
      expect(p.refeicoes.single.horario, '07:30');
    });

    test('envio não leva gramas e a cópia é independente', () {
      final p = Plano(nome: 'A', refeicoes: [
        Refeicao(nome: 'R', itens: [
          ItemRefeicao(alimentoId: 'A1', quantidade: 10, gramas: 10),
        ]),
      ]);
      final json = p.toJson();
      final item = ((json['refeicoes'] as List).first as Map)['itens'] as List;
      expect((item.first as Map).containsKey('gramas'), isFalse);

      final c = p.copia();
      c.refeicoes.first.itens.first.quantidade = 99;
      expect(p.refeicoes.first.itens.first.quantidade, 10);
    });
  });
}

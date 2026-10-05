import 'package:flutter_test/flutter_test.dart';

import 'package:nutri_app/models/alimento.dart';
import 'package:nutri_app/models/config_profissional.dart';
import 'package:nutri_app/models/plano.dart';
import 'package:nutri_app/services/pdf_plano.dart';
import 'package:nutri_app/utils/calculo_nutricional.dart';

void main() {
  final arroz = Alimento(
    id: 'A1',
    origem: 'TACO',
    nome: 'Arroz, integral, cozido',
    categoria: 'Cereais',
    energiaKcal: 124,
    proteinaG: 2.6,
    lipidiosG: 1,
    carboidratoG: 25.8,
    fibraG: 2.7,
    sodioMg: 1,
  );
  const colher = MedidaCaseira(
      id: 'M1', alimentoId: 'A1', descricao: 'Colher de sopa', gramas: 25);

  Plano plano() => Plano(
        nome: 'Plano 1800 kcal',
        metaKcal: 1800,
        dataInicio: '2026-10-05',
        observacoes: 'Beber 2 litros de água por dia.',
        refeicoes: [
          Refeicao(
            nome: 'Café da manhã',
            horario: '07:30',
            observacoes: 'Sem açúcar.',
            itens: [
              ItemRefeicao(
                alimentoId: 'A1',
                medidaCaseiraId: 'M1',
                quantidade: 3,
                gramas: 75,
                observacoes: 'Bem cozido',
              ),
            ],
          ),
          Refeicao(nome: 'Almoço'),
        ],
      );

  test('gera um PDF válido', () async {
    final bytes = await gerarPdfPlano(
      plano: plano(),
      nomePaciente: 'Fulana de Tal',
      alimentos: indexarAlimentos([arroz]),
      medidas: [colher],
      config: const ConfigProfissional(nome: 'Bárbara', crn: 'CRN-0 00000'),
    );
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(1000));
  });

  test('gera PDF mesmo sem dados da profissional e sem refeições', () async {
    final bytes = await gerarPdfPlano(
      plano: Plano(nome: 'Vazio'),
      nomePaciente: '',
      alimentos: const {},
      medidas: const [],
      config: const ConfigProfissional(),
    );
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  test('nome do arquivo sem acento e sem espaços', () {
    expect(nomeArquivoPdf(plano(), 'Fulana de Tal'),
        'plano-fulana-de-tal-plano-1800-kcal.pdf');
    expect(nomeArquivoPdf(Plano(), ''), 'plano-alimentar.pdf');
  });
}

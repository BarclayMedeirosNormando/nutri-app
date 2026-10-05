import '../utils/numeros.dart';

const statusPlano = ['rascunho', 'ativo', 'encerrado'];

const rotuloStatusPlano = {
  'rascunho': 'Rascunho',
  'ativo': 'Ativo',
  'encerrado': 'Encerrado',
};

/// Medida caseira de um alimento (ex.: "Colher de sopa" = 25 g).
class MedidaCaseira {
  const MedidaCaseira({
    required this.id,
    required this.alimentoId,
    required this.descricao,
    required this.gramas,
  });

  final String id;
  final String alimentoId;
  final String descricao;
  final double gramas;

  factory MedidaCaseira.fromJson(Map<String, dynamic> j) => MedidaCaseira(
        id: (j['id'] ?? '').toString(),
        alimentoId: (j['alimento_id'] ?? '').toString(),
        descricao: (j['descricao'] ?? '').toString(),
        gramas: paraDouble(j['gramas']) ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'alimento_id': alimentoId,
        'descricao': descricao,
        'gramas': gramas,
      };
}

/// Um alimento dentro de uma refeição. [quantidade] está em gramas, ou em
/// unidades da medida caseira quando [medidaCaseiraId] não é vazio.
/// [gramas] é o total em gramas (o servidor recalcula ao salvar).
class ItemRefeicao {
  ItemRefeicao({
    this.id = '',
    required this.alimentoId,
    this.medidaCaseiraId = '',
    this.quantidade = 100,
    this.gramas = 100,
    this.observacoes = '',
  });

  String id;
  String alimentoId;
  String medidaCaseiraId;
  double quantidade;
  double gramas;
  String observacoes;

  /// Atualiza [gramas] conforme [quantidade] e a medida escolhida (null = gramas).
  void recalcularGramas(MedidaCaseira? medida) {
    gramas = medida == null
        ? arredonda1(quantidade)
        : arredonda1(quantidade * medida.gramas);
  }

  ItemRefeicao copia() => ItemRefeicao(
        id: id,
        alimentoId: alimentoId,
        medidaCaseiraId: medidaCaseiraId,
        quantidade: quantidade,
        gramas: gramas,
        observacoes: observacoes,
      );

  factory ItemRefeicao.fromJson(Map<String, dynamic> j) => ItemRefeicao(
        id: (j['id'] ?? '').toString(),
        alimentoId: (j['alimento_id'] ?? '').toString(),
        medidaCaseiraId: (j['medida_caseira_id'] ?? '').toString(),
        quantidade: paraDouble(j['quantidade']) ?? 0,
        gramas: paraDouble(j['gramas']) ?? 0,
        observacoes: (j['observacoes'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'alimento_id': alimentoId,
        'medida_caseira_id': medidaCaseiraId,
        'quantidade': quantidade,
        'observacoes': observacoes,
      };
}

class Refeicao {
  Refeicao({
    this.id = '',
    this.nome = '',
    this.horario = '',
    this.observacoes = '',
    List<ItemRefeicao>? itens,
  }) : itens = itens ?? [];

  String id;
  String nome;

  /// 'HH:MM' ou vazio.
  String horario;
  String observacoes;
  final List<ItemRefeicao> itens;

  Refeicao copia() => Refeicao(
        id: id,
        nome: nome,
        horario: horario,
        observacoes: observacoes,
        itens: itens.map((i) => i.copia()).toList(),
      );

  factory Refeicao.fromJson(Map<String, dynamic> j) => Refeicao(
        id: (j['id'] ?? '').toString(),
        nome: (j['nome'] ?? '').toString(),
        horario: (j['horario'] ?? '').toString(),
        observacoes: (j['observacoes'] ?? '').toString(),
        itens: ((j['itens'] as List?) ?? const [])
            .map((e) => ItemRefeicao.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'horario': horario,
        'observacoes': observacoes,
        'itens': itens.map((i) => i.toJson()).toList(),
      };
}

class Plano {
  Plano({
    this.id = '',
    this.pacienteId = '',
    this.nome = '',
    this.dataInicio = '',
    this.dataFim = '',
    this.metaKcal,
    this.status = 'rascunho',
    this.observacoes = '',
    List<Refeicao>? refeicoes,
    this.totalRefeicoes = 0,
  }) : refeicoes = refeicoes ?? [];

  String id;
  String pacienteId;
  String nome;

  /// 'aaaa-mm-dd' ou vazio.
  String dataInicio;
  String dataFim;
  double? metaKcal;
  String status;
  String observacoes;
  final List<Refeicao> refeicoes;

  /// Preenchido só na listagem (o servidor não manda as refeições nela).
  int totalRefeicoes;

  Plano copia() => Plano(
        id: id,
        pacienteId: pacienteId,
        nome: nome,
        dataInicio: dataInicio,
        dataFim: dataFim,
        metaKcal: metaKcal,
        status: status,
        observacoes: observacoes,
        refeicoes: refeicoes.map((r) => r.copia()).toList(),
        totalRefeicoes: totalRefeicoes,
      );

  factory Plano.fromJson(Map<String, dynamic> j) => Plano(
        id: (j['id'] ?? '').toString(),
        pacienteId: (j['paciente_id'] ?? '').toString(),
        nome: (j['nome'] ?? '').toString(),
        dataInicio: (j['data_inicio'] ?? '').toString(),
        dataFim: (j['data_fim'] ?? '').toString(),
        metaKcal: paraDouble(j['meta_kcal']),
        status: (j['status'] ?? 'rascunho').toString(),
        observacoes: (j['observacoes'] ?? '').toString(),
        refeicoes: ((j['refeicoes'] as List?) ?? const [])
            .map((e) => Refeicao.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalRefeicoes: (j['total_refeicoes'] as num?)?.toInt() ?? 0,
      );

  /// Campos enviados ao servidor (as gramas dos itens são recalculadas lá).
  Map<String, dynamic> toJson() => {
        'id': id,
        'paciente_id': pacienteId,
        'nome': nome,
        'data_inicio': dataInicio,
        'data_fim': dataFim,
        'meta_kcal': metaKcal,
        'status': status,
        'observacoes': observacoes,
        'refeicoes': refeicoes.map((r) => r.toJson()).toList(),
      };
}

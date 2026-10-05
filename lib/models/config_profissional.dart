/// Dados da profissional que saem no cabeçalho do PDF.
class ConfigProfissional {
  const ConfigProfissional({this.nome = '', this.crn = '', this.contato = ''});

  final String nome;
  final String crn;
  final String contato;

  factory ConfigProfissional.fromJson(Map<String, dynamic> j) =>
      ConfigProfissional(
        nome: (j['nome'] ?? '').toString(),
        crn: (j['crn'] ?? '').toString(),
        contato: (j['contato'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {
        'nome': nome,
        'crn': crn,
        'contato': contato,
      };
}

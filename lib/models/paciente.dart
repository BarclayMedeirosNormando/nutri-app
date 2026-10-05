class Paciente {
  const Paciente({
    this.id = '',
    this.nome = '',
    this.dataNascimento = '',
    this.sexo = '',
    this.telefone = '',
    this.email = '',
    this.objetivo = '',
    this.observacoes = '',
    this.ativo = true,
    this.consentimentoEm = '',
  });

  final String id;
  final String nome;

  /// 'aaaa-mm-dd' ou vazio.
  final String dataNascimento;

  /// 'F', 'M', 'O' ou vazio.
  final String sexo;
  final String telefone;
  final String email;
  final String objetivo;
  final String observacoes;
  final bool ativo;

  /// Timestamp do consentimento LGPD vigente; vazio se não registrado.
  final String consentimentoEm;

  bool get temConsentimento => consentimentoEm.isNotEmpty;

  factory Paciente.fromJson(Map<String, dynamic> j) {
    String s(String k) => (j[k] ?? '').toString();
    return Paciente(
      id: s('id'),
      nome: s('nome'),
      dataNascimento: s('data_nascimento'),
      sexo: s('sexo'),
      telefone: s('telefone'),
      email: s('email'),
      objetivo: s('objetivo'),
      observacoes: s('observacoes'),
      ativo: j['ativo'] != false,
      consentimentoEm: s('consentimento_em'),
    );
  }

  /// Campos enviados ao servidor (o consentimento vai em parâmetro separado).
  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'data_nascimento': dataNascimento,
        'sexo': sexo,
        'telefone': telefone,
        'email': email,
        'objetivo': objetivo,
        'observacoes': observacoes,
      };
}

String _dois(int n) => n.toString().padLeft(2, '0');

/// 'aaaa-mm-dd' -> 'dd/mm/aaaa' ('' se não for uma data válida).
String isoParaBr(String iso) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(iso);
  if (m == null) return '';
  return '${m[3]}/${m[2]}/${m[1]}';
}

/// 'dd/mm/aaaa' -> 'aaaa-mm-dd'. Devolve '' se vazio e null se inválida ou futura.
String? brParaIso(String br) {
  final t = br.trim();
  if (t.isEmpty) return '';
  final m = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(t);
  if (m == null) return null;
  final d = int.parse(m[1]!);
  final mo = int.parse(m[2]!);
  final y = int.parse(m[3]!);
  final dt = DateTime(y, mo, d);
  if (dt.year != y || dt.month != mo || dt.day != d) return null;
  if (dt.isAfter(DateTime.now())) return null;
  return '${m[3]}-${m[2]}-${m[1]}';
}

/// 'dd/mm/aaaa' -> 'aaaa-mm-dd', aceitando qualquer data válida (inclusive futura).
/// Devolve '' se vazio e null se inválida.
String? brParaIsoLivre(String br) {
  final t = br.trim();
  if (t.isEmpty) return '';
  final m = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(t);
  if (m == null) return null;
  final d = int.parse(m[1]!);
  final mo = int.parse(m[2]!);
  final y = int.parse(m[3]!);
  final dt = DateTime(y, mo, d);
  if (dt.year != y || dt.month != mo || dt.day != d) return null;
  return '${m[3]}-${m[2]}-${m[1]}';
}

/// Idade em anos a partir de 'aaaa-mm-dd' (null se não houver data válida).
int? idadeDe(String iso) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(iso);
  if (m == null) return null;
  final nasc = DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  final hoje = DateTime.now();
  var idade = hoje.year - nasc.year;
  if (hoje.month < nasc.month ||
      (hoje.month == nasc.month && hoje.day < nasc.day)) {
    idade--;
  }
  return idade;
}

/// Timestamp ISO (UTC) -> 'dd/mm/aaaa' no fuso local.
String dataDeTimestamp(String ts) {
  final d = DateTime.tryParse(ts);
  if (d == null) return '';
  final l = d.toLocal();
  return '${_dois(l.day)}/${_dois(l.month)}/${l.year}';
}

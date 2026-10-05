/// Converte número, texto ("3,5" ou "3.5") ou nulo em double; vazio/inválido vira null.
double? paraDouble(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  final s = v.toString().trim().replaceAll(',', '.');
  if (s.isEmpty) return null;
  return double.tryParse(s);
}

/// Arredonda para 1 casa decimal (mesma regra do servidor para as gramas).
double arredonda1(double v) => (v * 10).round() / 10;

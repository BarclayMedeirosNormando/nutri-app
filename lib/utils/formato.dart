/// Número com vírgula decimal e [casas] casas fixas (ex.: 1850,5).
String fmtNum(double v, [int casas = 1]) =>
    v.toStringAsFixed(casas).replaceAll('.', ',');

/// Gramas: inteiro quando for redondo (75), senão 1 casa (75,5).
String fmtG(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : fmtNum(v, 1);

/// Texto para campos de digitação: sem casas sobrando (3, 0,25, 12,5).
String fmtCampo(double v) {
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  return v.toString().replaceAll('.', ',');
}

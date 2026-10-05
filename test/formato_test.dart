import 'package:flutter_test/flutter_test.dart';

import 'package:nutri_app/utils/datas.dart';
import 'package:nutri_app/utils/formato.dart';

void main() {
  test('formatação de números', () {
    expect(fmtNum(1850.456, 0), '1850');
    expect(fmtNum(12.34), '12,3');
    expect(fmtG(75), '75');
    expect(fmtG(75.5), '75,5');
    expect(fmtCampo(3), '3');
    expect(fmtCampo(0.25), '0,25');
  });

  test('brParaIsoLivre aceita datas futuras e recusa inválidas', () {
    expect(brParaIsoLivre(''), '');
    expect(brParaIsoLivre('05/10/2099'), '2099-10-05');
    expect(brParaIsoLivre('31/02/2026'), isNull);
    expect(brParaIsoLivre('2026-10-05'), isNull);
  });
}

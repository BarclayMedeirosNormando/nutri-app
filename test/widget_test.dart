import 'package:flutter_test/flutter_test.dart';

import 'package:nutri_app/main.dart';

void main() {
  testWidgets('abre na tela de login', (WidgetTester tester) async {
    await tester.pumpWidget(const NutriApp());

    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('Primeiro acesso'), findsOneWidget);
  });
}

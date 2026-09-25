import 'package:flutter_test/flutter_test.dart';

import 'package:transmission_numerique/main.dart';

void main() {
  testWidgets('La page de connexion est affichee', (WidgetTester tester) async {
    await tester.pumpWidget(const CahierTransmissionApp());

    expect(find.text('Cahier de transmission'), findsOneWidget);
    expect(find.text('Connexion'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
  });
}

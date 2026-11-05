import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transmission_numerique/pages/widgets/signature_capture.dart';

void main() {
  testWidgets('Valider conserve la signature et Effacer la supprime',
      (tester) async {
    final key = GlobalKey<SignatureCaptureState>();
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: SignatureCapture(key: key))),
    );

    await tester.tap(find.text('Ouvrir la signature'));
    await tester.pumpAndSettle();

    expect(find.text('Signature du bénéficiaire'), findsOneWidget);
    expect(find.text('Effacer'), findsOneWidget);
    expect(find.text('Annuler'), findsOneWidget);
    expect(find.text('Valider'), findsOneWidget);

    await tester.drag(
      find.byKey(const Key('signature-drawing-area')),
      const Offset(90, -20),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();

    expect(key.currentState!.hasSignature, isTrue);
    expect(find.byKey(const Key('signature-preview')), findsOneWidget);

    // Effacer dans la fenêtre puis Annuler ne doit pas supprimer l'original.
    await tester.tap(find.text('Modifier la signature'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Effacer'));
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(key.currentState!.hasSignature, isTrue);

    // Effacer + Valider doit bien vider la signature.
    await tester.tap(find.text('Modifier la signature'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Effacer'));
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();
    expect(key.currentState!.hasSignature, isFalse);
  });

  testWidgets('Le dialogue reste utilisable sur tablette horizontale',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 720);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SignatureCapture())),
    );
    await tester.tap(find.text('Ouvrir la signature'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('signature-drawing-area')), findsOneWidget);
    expect(find.text('Effacer'), findsOneWidget);
    expect(find.text('Valider'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

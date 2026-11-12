import 'package:flutter_test/flutter_test.dart';
import 'package:transmission_numerique/models/transmission.dart';

void main() {
  test('ordinateur propose trois accessoires cochés avec même quantité', () {
    final accessoires = defaultComputerAccessories('Ordinateur', 2);
    expect(accessoires.map((item) => item.equipmentType),
        ['Souris', 'Sacoche de transport', 'Chargeur']);
    expect(accessoires.map((item) => item.quantity), [2, 2, 2]);
    expect(defaultComputerAccessories('Écran', 1), isEmpty);
  });

  test('une ancienne transmission sans equipmentItems est conservée', () {
    final item = Transmission.fromJson({
      'id': '1', 'type': 'don', 'equipmentType': 'Ordinateur',
      'quantity': 1, 'beneficiary': 'Service',
    });
    expect(item.allItems.length, 1);
    expect(item.allItems.first.label, 'Ordinateur');
  });

  test('une nouvelle transmission contient tous les matériels', () {
    final item = Transmission.fromJson({
      'id': '2', 'type': 'don', 'equipmentType': 'Ordinateur',
      'quantity': 1, 'beneficiary': 'Service',
      'equipmentItems': [
        {'equipmentType': 'Ordinateur', 'quantity': 1},
        {'equipmentType': 'Souris', 'quantity': 1},
        {'equipmentType': 'Sacoche de transport', 'quantity': 1},
        {'equipmentType': 'Chargeur', 'quantity': 1},
      ],
    });
    expect(item.allItems.length, 4);
    expect(item.allItems.last.label, 'Chargeur');
  });
}

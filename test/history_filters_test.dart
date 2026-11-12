import 'package:flutter_test/flutter_test.dart';
import '../lib/models/transmission.dart';
import '../lib/pages/widgets/history_filters.dart';

Transmission item({
  required String id,
  required TransmissionType type,
  LoanStatus? status,
  required int year,
  String beneficiary = 'Service informatique',
}) => Transmission(
  id: id,
  type: type,
  equipmentType: 'Écran',
  equipmentModel: null,
  customEquipment: null,
  quantity: 1,
  beneficiary: beneficiary,
  content: '',
  author: 'agent',
  createdAt: DateTime.utc(year, 6, 5),
  loanStatus: status,
  returnedAt: null,
  returnedBy: null,
);

void main() {
  final entries = [
    item(id: 'a', type: TransmissionType.don, year: 2025),
    item(id: 'b', type: TransmissionType.pret,
        status: LoanStatus.enCours, year: 2026),
    item(id: 'c', type: TransmissionType.pret,
        status: LoanStatus.rendu, year: 2026),
    item(id: 'd', type: TransmissionType.pret,
        year: 2024, beneficiary: 'Service RH'),
  ];

  test('années disponibles issues des données réelles', () {
    expect(historyYears(entries), [2026, 2025, 2024]);
  });

  test('dons uniquement', () {
    expect(filterHistory(entries, category: HistoryCategory.dons)
        .map((e) => e.id), ['a']);
  });

  test('prêts en cours inclut les anciens prêts sans statut', () {
    expect(filterHistory(entries, category: HistoryCategory.enCours)
        .map((e) => e.id), ['b', 'd']);
  });

  test('prêts rendus', () {
    expect(filterHistory(entries, category: HistoryCategory.rendus)
        .map((e) => e.id), ['c']);
  });

  test('combinaison année, type et recherche', () {
    expect(filterHistory(entries,
        category: HistoryCategory.prets,
        year: 2024,
        query: 'rh').map((e) => e.id), ['d']);
  });
}

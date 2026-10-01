import 'dart:convert';

import 'package:excel/excel.dart';

import '../models/transmission.dart';
import 'download_file.dart';

enum HistoryExportFormat { csv, json, xlsx }

/// Exporte la liste effectivement chargée dans la page Web.
/// La recherche est appliquée par GET /transmissions?q=... AVANT cette étape.
class HistoryExport {
  const HistoryExport._();

  static const _columns = <String>[
    'ID',
    'Date de saisie',
    'Type',
    'Matériel',
    'Modèle',
    'Autre matériel',
    'Quantité',
    'Bénéficiaire / service',
    'Commentaire du don / prêt',
    'Saisi par',
    'Statut du prêt',
    'Date de retour',
    'Rendu par',
    'Commentaire au retour',
  ];

  static String _date(DateTime? date) {
    if (date == null) return '';
    final local = date.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  static List<Object?> _row(Transmission item) => <Object?>[
        item.id,
        _date(item.createdAt),
        item.type.label,
        item.equipmentType,
        item.equipmentModel ?? '',
        item.customEquipment ?? '',
        item.quantity,
        item.beneficiary,
        item.content,
        item.author,
        item.type == TransmissionType.pret
            ? (item.loanStatus ?? LoanStatus.enCours).label
            : '',
        _date(item.returnedAt),
        item.returnedBy ?? '',
        item.returnComment ?? '',
      ];

  // JSON volontairement structuré pour un réemploi ultérieur (ISO 8601).
  static Map<String, Object?> _jsonRow(Transmission item) => <String, Object?>{
        'id': item.id,
        'createdAt': item.createdAt.toUtc().toIso8601String(),
        'type': item.type.apiValue,
        'equipmentType': item.equipmentType,
        'equipmentModel': item.equipmentModel,
        'customEquipment': item.customEquipment,
        'quantity': item.quantity,
        'beneficiary': item.beneficiary,
        'content': item.content,
        'author': item.author,
        'loanStatus': item.type == TransmissionType.pret
            ? (item.loanStatus ?? LoanStatus.enCours).apiValue
            : null,
        'returnedAt': item.returnedAt?.toUtc().toIso8601String(),
        'returnedBy': item.returnedBy,
        'returnComment': item.returnComment,
      };

  /// Les exports CSV sont régulièrement ouverts avec Excel. Préfixer les
  /// chaînes commençant par = + - @ (même après des espaces) évite une
  /// interprétation en formule lors de l'ouverture du fichier.
  static String _safeCsvText(String text) {
    if (RegExp(r'^\s*[=+\-@]').hasMatch(text)) return "'$text";
    return text;
  }

  static String _csvCell(Object? value) {
    final text = _safeCsvText(value?.toString() ?? '');
    return '"${text.replaceAll('"', '""')}"';
  }

  static void export(List<Transmission> items, HistoryExportFormat format) {
    if (items.isEmpty) {
      throw StateError('Aucune transmission à exporter.');
    }

    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    final stamp = '${now.year}-${two(now.month)}-${two(now.day)}_'
        '${two(now.hour)}${two(now.minute)}';
    final basename = 'digital-logbook_historique_$stamp';

    switch (format) {
      case HistoryExportFormat.csv:
        // BOM UTF-8 et séparateur « ; » pour Excel configuré en français.
        final lines = <List<Object?>>[
          _columns,
          ...items.map(_row),
        ];
        final csv = '\uFEFF${lines.map((row) => row.map(_csvCell).join(';')).join('\r\n')}\r\n';
        downloadFile(
          fileName: '$basename.csv',
          mimeType: 'text/csv;charset=utf-8',
          bytes: utf8.encode(csv),
        );
        return;

      case HistoryExportFormat.json:
        downloadFile(
          fileName: '$basename.json',
          mimeType: 'application/json;charset=utf-8',
          bytes: utf8.encode(
            const JsonEncoder.withIndent('  ')
                .convert(items.map(_jsonRow).toList()),
          ),
        );
        return;

      case HistoryExportFormat.xlsx:
        final workbook = Excel.createExcel();
        workbook.rename(workbook.getDefaultSheet() ?? 'Sheet1', 'Historique');
        final sheet = workbook['Historique'];
        sheet.appendRow(_columns.map((text) => TextCellValue(text)).toList());
        final heading = CellStyle(bold: true);
        for (var col = 0; col < _columns.length; col++) {
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0))
              .cellStyle = heading;
          sheet.setColumnWidth(
            col,
            switch (col) {
              0 => 39,
              1 || 11 => 21,
              8 || 13 => 48,
              7 => 28,
              _ => 22,
            },
          );
        }
        for (final item in items) {
          sheet.appendRow(<CellValue?>[
            for (final value in _row(item))
              value == null
                  ? null
                  : value is int
                      ? IntCellValue(value)
                      : TextCellValue(value.toString()),
          ]);
        }
        final bytes = workbook.encode();
        if (bytes == null) {
          throw StateError('Impossible de générer le fichier Excel.');
        }
        downloadFile(
          fileName: '$basename.xlsx',
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          bytes: bytes,
        );
        return;
    }
  }
}

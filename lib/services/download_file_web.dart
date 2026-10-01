// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

void downloadFile({
  required String fileName,
  required String mimeType,
  required List<int> bytes,
}) {
  final blob = html.Blob(<Object>[Uint8List.fromList(bytes)], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)..download = fileName;
  html.document.body?.append(anchor);
  try {
    // La même fonction est utilisée pour les trois formats : un seul clic,
    // aucun envoi vers un service tiers.
    anchor.click();
  } finally {
    anchor.remove();
    // Ne pas révoquer le Blob immédiatement : laisser Edge/Chrome commencer
    // effectivement le téléchargement, même pour un historique volumineux.
    unawaited(Future<void>.delayed(const Duration(seconds: 10), () {
      html.Url.revokeObjectUrl(url);
    }));
  }
}

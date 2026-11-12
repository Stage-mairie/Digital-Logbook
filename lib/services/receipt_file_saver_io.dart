import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';

const _channel = MethodChannel('digital_logbook/pdf_saver');

Future<bool> saveReceiptFile({
  required String fileName,
  required Uint8List bytes,
}) async {
  if (!Platform.isAndroid) {
    throw UnsupportedError('Enregistrement PDF disponible uniquement sur Web et Android.');
  }
  try {
    final saved = await _channel.invokeMethod<bool>('savePdf', {
      'fileName': fileName,
      'bytes': bytes,
    });
    return saved == true;
  } on PlatformException catch (error) {
    throw Exception(error.message ?? 'Impossible de sauvegarder le PDF.');
  }
}

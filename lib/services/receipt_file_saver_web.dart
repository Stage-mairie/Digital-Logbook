import 'dart:typed_data';

import 'download_file.dart';

Future<bool> saveReceiptFile({
  required String fileName,
  required Uint8List bytes,
}) async {
  downloadFile(fileName: fileName, mimeType: 'application/pdf', bytes: bytes);
  return true;
}

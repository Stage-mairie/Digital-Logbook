import 'package:flutter/material.dart';

import '../../models/transmission.dart';
import '../../services/receipt_file_saver.dart';
import '../../services/transmission_service.dart';

/// Téléchargement du reçu signé, avec gestion du chargement et des erreurs.
class ReceiptDownloadButton extends StatefulWidget {
  final Transmission transmission;
  final TransmissionService service;

  const ReceiptDownloadButton({
    super.key,
    required this.transmission,
    required this.service,
  });

  @override
  State<ReceiptDownloadButton> createState() => _ReceiptDownloadButtonState();
}

class _ReceiptDownloadButtonState extends State<ReceiptDownloadButton> {
  bool _busy = false;

  Future<void> _download() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await widget.service.getReceiptPdf(widget.transmission.id);
      final date = widget.transmission.createdAt;
      final day = '${date.year.toString().padLeft(4, '0')}'
          '${date.month.toString().padLeft(2, '0')}'
          '${date.day.toString().padLeft(2, '0')}';
      final idPart = widget.transmission.id.length >= 8
          ? widget.transmission.id.substring(0, 8)
          : widget.transmission.id;
      final fileName = 'Bon_${widget.transmission.type.apiValue}_${day}_$idPart.pdf';
      final saved = await saveReceiptFile(fileName: fileName, bytes: bytes);
      if (!mounted) return;
      if (saved) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('PDF téléchargé ou enregistré.'),
        ));
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Impossible de télécharger le reçu : $error'),
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Télécharger le reçu PDF',
      child: IconButton(
        key: ValueKey('receipt-${widget.transmission.id}'),
        onPressed: _busy ? null : _download,
        icon: _busy
            ? const SizedBox(
                width: 21,
                height: 21,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              )
            : const Icon(Icons.file_download_outlined,
                color: Color(0xFF214B55), size: 23),
      ),
    );
  }
}

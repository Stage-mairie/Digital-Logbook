import 'package:flutter/material.dart';

/// null = annulation, chaîne vide = retour confirmé sans commentaire.
Future<String?> showReturnLoanDialog(
  BuildContext context,
  String equipmentLabel,
) {
  return showDialog<String>(
    context: context,
    builder: (_) => _ReturnLoanDialog(equipmentLabel: equipmentLabel),
  );
}

class _ReturnLoanDialog extends StatefulWidget {
  final String equipmentLabel;

  const _ReturnLoanDialog({required this.equipmentLabel});

  @override
  State<_ReturnLoanDialog> createState() => _ReturnLoanDialogState();
}

class _ReturnLoanDialogState extends State<_ReturnLoanDialog> {
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirmer le retour'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Marquer le prêt « ${widget.equipmentLabel} » comme rendu ?'),
            const SizedBox(height: 18),
            TextField(
              controller: _commentController,
              maxLength: 1000,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Commentaire au retour (facultatif)',
                hintText: 'État du matériel, accessoires manquants…',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(
            _commentController.text.trim(),
          ),
          icon: const Icon(Icons.assignment_turned_in_outlined),
          label: const Text('Marquer comme rendu'),
        ),
      ],
    );
  }
}

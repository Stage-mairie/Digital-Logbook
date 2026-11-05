import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Seule une image PNG est envoyée au serveur.
/// Le tracé reste local au formulaire jusqu'à l'enregistrement.
class SignatureCapture extends StatefulWidget {
  const SignatureCapture({super.key});

  @override
  State<SignatureCapture> createState() => SignatureCaptureState();
}

class SignatureCaptureState extends State<SignatureCapture> {
  List<List<Offset>> _strokes = [];

  bool get hasSignature => _strokes.any((stroke) => stroke.isNotEmpty);

  void clear() {
    setState(() => _strokes = []);
  }

  Future<void> _openSignatureEditor() async {
    // Ferme le clavier, qui réduirait la place disponible en mode paysage.
    FocusManager.instance.primaryFocus?.unfocus();

    final updatedStrokes = await showDialog<List<List<Offset>>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SignatureEditor(initialStrokes: _copyStrokes(_strokes)),
    );

    // Annuler ne modifie jamais la signature déjà enregistrée dans le formulaire.
    if (!mounted || updatedStrokes == null) return;
    setState(() => _strokes = updatedStrokes);
  }

  Future<Uint8List?> exportPng() async {
    if (!hasSignature) return null;

    // Export indépendant de la taille (portrait/paysage) du widget affiché.
    const width = 1200;
    const height = 400;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    _SignaturePainter(_strokes).paint(
      canvas,
      const Size(1200, 400),
    );

    final picture = recorder.endRecording();
    try {
      final image = await picture.toImage(width, height);
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        return bytes?.buffer.asUint8List();
      } finally {
        image.dispose();
      }
    } finally {
      picture.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final signed = hasSignature;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Signature du bénéficiaire (facultative)',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _openSignatureEditor,
          icon: Icon(signed ? Icons.edit_outlined : Icons.draw_outlined),
          label: Text(signed ? 'Modifier la signature' : 'Ouvrir la signature'),
        ),
        const SizedBox(height: 10),
        if (signed) ...[
          Container(
            key: const Key('signature-preview'),
            height: 105,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFB8D2D8)),
              borderRadius: BorderRadius.circular(10),
            ),
            clipBehavior: Clip.antiAlias,
            child: CustomPaint(
              painter: _SignaturePainter(_strokes),
              child: const SizedBox.expand(),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: clear,
              icon: const Icon(Icons.restart_alt, size: 18),
              label: const Text('Effacer la signature'),
            ),
          ),
        ] else
          const Text(
            'Aucune signature. Touchez le bouton pour signer dans une fenêtre dédiée.',
            style: TextStyle(fontSize: 12, color: Color(0xFF62818A)),
          ),
      ],
    );
  }
}

List<List<Offset>> _copyStrokes(List<List<Offset>> strokes) => [
      for (final stroke in strokes) List<Offset>.from(stroke),
    ];

class _SignatureEditor extends StatefulWidget {
  const _SignatureEditor({required this.initialStrokes});

  final List<List<Offset>> initialStrokes;

  @override
  State<_SignatureEditor> createState() => _SignatureEditorState();
}

class _SignatureEditorState extends State<_SignatureEditor> {
  final GlobalKey _canvasKey = GlobalKey();
  late List<List<Offset>> _strokes;
  int? _activePointer;

  @override
  void initState() {
    super.initState();
    _strokes = _copyStrokes(widget.initialStrokes);
  }

  Offset _normalizedPosition(PointerEvent event) {
    final renderBox = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    final size = renderBox?.size ?? Size.zero;
    if (size.width <= 0 || size.height <= 0) return Offset.zero;
    return Offset(
      (event.localPosition.dx / size.width).clamp(0.0, 1.0).toDouble(),
      (event.localPosition.dy / size.height).clamp(0.0, 1.0).toDouble(),
    );
  }

  void _start(PointerDownEvent event) {
    if (_activePointer != null) return;
    setState(() {
      _activePointer = event.pointer;
      _strokes.add([_normalizedPosition(event)]);
    });
  }

  void _move(PointerMoveEvent event) {
    if (_activePointer != event.pointer || _strokes.isEmpty) return;
    setState(() => _strokes.last.add(_normalizedPosition(event)));
  }

  void _finish(PointerEvent event) {
    if (_activePointer == event.pointer) _activePointer = null;
  }

  void _clear() {
    setState(() {
      _activePointer = null;
      _strokes.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final availableHeight = MediaQuery.sizeOf(context).height -
        MediaQuery.viewInsetsOf(context).bottom;
    // Le cadre s'adapte aux tablettes horizontales et aux petits écrans.
    final drawingHeight = (availableHeight * 0.34).clamp(95.0, 260.0).toDouble();

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.draw_outlined),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Signature du bénéficiaire',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Annuler et fermer',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Signez uniquement à l’intérieur du cadre blanc avec le doigt ou le stylet.',
                style: TextStyle(fontSize: 12, color: Color(0xFF62818A)),
              ),
              const SizedBox(height: 12),
              Container(
                key: const Key('signature-drawing-area'),
                height: drawingHeight,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFF829DA4), width: 1.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                clipBehavior: Clip.antiAlias,
                child: Listener(
                  key: _canvasKey,
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: _start,
                  onPointerMove: _move,
                  onPointerUp: _finish,
                  onPointerCancel: _finish,
                  child: CustomPaint(
                    painter: _SignaturePainter(_strokes),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OverflowBar(
                alignment: MainAxisAlignment.end,
                spacing: 8,
                overflowSpacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: _clear,
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Effacer'),
                  ),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Annuler'),
                  ),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(
                      _copyStrokes(_strokes),
                    ),
                    icon: const Icon(Icons.check),
                    label: const Text('Valider'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Les coordonnées sont normalisées (0..1) : pas de décalage ni de découpe
/// lors du passage portrait/paysage ou de la génération du PNG.
class _SignaturePainter extends CustomPainter {
  const _SignaturePainter(this.strokes);

  final List<List<Offset>> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);

    final paint = Paint()
      ..color = const Color(0xFF182C32)
      ..strokeWidth = math.max(2.5, size.height * 0.007)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;
      Offset scaled(Offset p) => Offset(p.dx * size.width, p.dy * size.height);
      if (stroke.length == 1) {
        canvas.drawCircle(scaled(stroke.first), paint.strokeWidth / 2,
            Paint()..color = paint.color);
        continue;
      }
      final first = scaled(stroke.first);
      final path = Path()..moveTo(first.dx, first.dy);
      for (final point in stroke.skip(1)) {
        final p = scaled(point);
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}

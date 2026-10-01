import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Seule l'image statique PNG est envoyée au serveur.
/// Les mouvements/pressions du stylet ne sont jamais persistés.
class SignatureCapture extends StatefulWidget {
  const SignatureCapture({super.key});

  @override
  State<SignatureCapture> createState() => SignatureCaptureState();
}

class SignatureCaptureState extends State<SignatureCapture> {
  final GlobalKey _imageKey = GlobalKey();
  final List<List<Offset>> _strokes = [];
  int? _activePointer;

  bool get hasSignature => _strokes.any((stroke) => stroke.isNotEmpty);

  void clear() {
    setState(() {
      _strokes.clear();
      _activePointer = null;
    });
  }

  Future<Uint8List?> exportPng() async {
    if (!hasSignature) return null;
    await WidgetsBinding.instance.endOfFrame;
    final boundary = _imageKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 1.5);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      return bytes?.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  void _start(PointerDownEvent event) {
    if (_activePointer != null) return;
    setState(() {
      _activePointer = event.pointer;
      _strokes.add(<Offset>[event.localPosition]);
    });
  }

  void _move(PointerMoveEvent event) {
    if (_activePointer != event.pointer || _strokes.isEmpty) return;
    setState(() => _strokes.last.add(event.localPosition));
  }

  void _finish(PointerEvent event) {
    if (_activePointer == event.pointer) _activePointer = null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Signature du bénéficiaire (facultative)',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            TextButton.icon(
              onPressed: clear,
              icon: const Icon(Icons.restart_alt, size: 18),
              label: const Text('Effacer'),
            ),
          ],
        ),
        Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _start,
          onPointerMove: _move,
          onPointerUp: _finish,
          onPointerCancel: _finish,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFB8D2D8)),
              borderRadius: BorderRadius.circular(10),
            ),
            clipBehavior: Clip.antiAlias,
            child: RepaintBoundary(
              key: _imageKey,
              child: Container(
                color: Colors.white,
                height: 165,
                width: double.infinity,
                child: CustomPaint(painter: _SignaturePainter(_strokes)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text('Signer dans le cadre blanc avec le doigt ou le stylet. '
            'Cette image confirme la remise du matériel ; elle ne vérifie pas l’identité.',
            style: TextStyle(fontSize: 12, color: Color(0xFF62818A))),
      ],
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  const _SignaturePainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF182C32)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final points in strokes) {
      if (points.isEmpty) continue;
      if (points.length == 1) {
        canvas.drawCircle(points.first, 1.3, Paint()..color = paint.color);
        continue;
      }
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}

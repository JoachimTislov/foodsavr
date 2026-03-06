import 'package:flutter/material.dart';

class BarcodeScannerOverlay extends StatelessWidget {
  const BarcodeScannerOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BarcodeScannerOverlayPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _BarcodeScannerOverlayPainter extends CustomPainter {
  static const _overlayColor = Color(0xAA000000);
  static const _holeWidth = 280.0;
  static const _holeHeight = 180.0;

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()..color = _overlayColor;
    final overlayPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final scanRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: size.center(Offset.zero),
        width: _holeWidth,
        height: _holeHeight,
      ),
      const Radius.circular(20),
    );
    final holePath = Path()..addRRect(scanRect);
    final combined = Path.combine(
      PathOperation.difference,
      overlayPath,
      holePath,
    );
    canvas.drawPath(combined, overlayPaint);

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(scanRect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

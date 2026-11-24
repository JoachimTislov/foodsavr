import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../constants/material3_config.dart';

class BarcodeScannerOverlay extends StatelessWidget {
  const BarcodeScannerOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BarcodeScannerOverlayPainter(
        Theme.of(context).colorScheme.primary,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _BarcodeScannerOverlayPainter extends CustomPainter {
  _BarcodeScannerOverlayPainter(this.borderColor);

  final Color borderColor;

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
        width: math.min(_holeWidth, size.width * 0.85),
        height: math.min(_holeHeight, size.height * 0.65),
      ),
      const Radius.circular(Material3Config.radiusLarge),
    );
    final holePath = Path()..addRRect(scanRect);
    final combined = Path.combine(
      PathOperation.difference,
      overlayPath,
      holePath,
    );
    canvas.drawPath(combined, overlayPaint);

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(scanRect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _BarcodeScannerOverlayPainter oldDelegate) =>
      oldDelegate.borderColor != borderColor;
}

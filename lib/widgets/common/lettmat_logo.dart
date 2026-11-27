import 'package:flutter/material.dart';
import 'package:vector_graphics/vector_graphics.dart';

/// Displays the LettMat leaf mark on a transparent background.
class LettMatLogo extends StatelessWidget {
  static const assetPath = 'assets/logos/lettmat-logo.svg';
  static const brandColor = Color(0xFF13C8EC);
  static const leafColor = Color(0xFF0F172A);

  final double size;
  final String? semanticsLabel;

  const LettMatLogo({super.key, this.size = 64, this.semanticsLabel});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: VectorGraphic(
        loader: const AssetBytesLoader(assetPath),
        width: size,
        height: size,
        semanticsLabel: semanticsLabel,
        placeholderBuilder: (_) => _LettMatLogoFallback(size: size),
      ),
    );
  }
}

class _LettMatLogoFallback extends StatelessWidget {
  final double size;

  const _LettMatLogoFallback({required this.size});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: LettMatLogo.brandColor,
        borderRadius: BorderRadius.circular(size * 0.25),
      ),
      child: Center(
        child: Icon(Icons.eco, color: LettMatLogo.leafColor, size: size * 0.56),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Menggambar [path] sebagai garis putus-putus.
void drawDashed(
  Canvas canvas,
  Path path,
  Paint paint, {
  double dash = 4,
  double gap = 5,
}) {
  for (final metric in path.computeMetrics()) {
    double d = 0;
    while (d < metric.length) {
      final end = d + dash < metric.length ? d + dash : metric.length;
      canvas.drawPath(metric.extractPath(d, end), paint);
      d += dash + gap;
    }
  }
}

final Path _plane = _buildPlane();

/// Pesawat menghadap ke kanan, berpusat di (0, 0).
Path _buildPlane() {
  return Path()
    ..moveTo(11, 0)
    ..cubicTo(11, -1.8, 7, -3, 3, -3)
    ..lineTo(-7, -3)
    ..lineTo(-11, -8)
    ..lineTo(-14, -8)
    ..lineTo(-11, 0)
    ..lineTo(-14, 8)
    ..lineTo(-11, 8)
    ..lineTo(-7, 3)
    ..lineTo(3, 3)
    ..cubicTo(7, 3, 11, 1.8, 11, 0)
    ..close()
    ..moveTo(1, -3)
    ..lineTo(-4, -14)
    ..lineTo(-8, -14)
    ..lineTo(-4, -3)
    ..close()
    ..moveTo(1, 3)
    ..lineTo(-4, 14)
    ..lineTo(-8, 14)
    ..lineTo(-4, 3)
    ..close();
}

int alphaOf(double opacity) => (opacity.clamp(0.0, 1.0) * 255).round();

void drawPlane(Canvas canvas, {double opacity = 1}) {
  final a = alphaOf(opacity);
  canvas.drawPath(_plane, Paint()..color = AppColors.gold.withAlpha(a));
  canvas.drawPath(
    _plane,
    Paint()
      ..color = AppColors.ink.withAlpha(a)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeJoin = StrokeJoin.round,
  );
}

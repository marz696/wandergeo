import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Lingkaran teal yang tergambar, lalu centang emas.
class AnimatedCheck extends StatelessWidget {
  const AnimatedCheck({super.key, this.size = 84});

  final double size;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeOut,
      builder: (_, t, __) =>
          CustomPaint(size: Size.square(size), painter: _CheckPainter(t)),
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 84);
    final ring = Paint()
      ..color = AppColors.teal
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final circle = Path()
      ..addOval(Rect.fromCircle(center: const Offset(42, 42), radius: 38));
    final ringT = (t / .55).clamp(0.0, 1.0);
    for (final m in circle.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * ringT), ring);
    }

    final checkT = ((t - .45) / .55).clamp(0.0, 1.0);
    final check = Path()
      ..moveTo(26, 43)
      ..lineTo(37, 54)
      ..lineTo(58, 30);
    final tick = Paint()
      ..color = AppColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final m in check.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * checkT), tick);
    }
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.t != t;
}

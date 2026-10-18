import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../data/feedback_repository.dart';

/// Wajah rating 1 (sangat kecewa) sampai 5 (sangat senang), digambar dengan
/// CustomPaint supaya tidak bergantung pada emoji bawaan perangkat.
class RatingFace extends StatelessWidget {
  const RatingFace({
    super.key,
    required this.level,
    this.selected = true,
    this.size = 44,
  });

  final int level;
  final bool selected;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Rating $level: ${kRatingLabels[level - 1]}',
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: selected ? 1 : .35,
        child: CustomPaint(size: Size.square(size), painter: _FacePainter(level)),
      ),
    );
  }
}

class _FacePainter extends CustomPainter {
  const _FacePainter(this.level);

  final int level;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 40; // gambar dirancang pada kotak 40 x 40
    Offset p(double x, double y) => Offset(x * k, y * k);

    canvas.drawCircle(p(20, 20), 19 * k, Paint()..color = AppColors.gold);

    final ink = Paint()..color = AppColors.ink;
    final line = Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * k
      ..strokeCap = StrokeCap.round;

    if (level == 5) {
      final star = Paint()..color = const Color(0xFFE8590C);
      for (final cx in const [14.0, 26.0]) {
        canvas.drawPath(
          Path()
            ..moveTo(cx * k, 11 * k)
            ..lineTo((cx + 3) * k, 16 * k)
            ..lineTo(cx * k, 21 * k)
            ..lineTo((cx - 3) * k, 16 * k)
            ..close(),
          star,
        );
      }
      canvas.drawPath(
        Path()
          ..moveTo(12 * k, 24 * k)
          ..quadraticBezierTo(20 * k, 33 * k, 28 * k, 24 * k)
          ..close(),
        ink,
      );
      return;
    }

    canvas.drawCircle(p(14, 16), 2 * k, ink);
    canvas.drawCircle(p(26, 16), 2 * k, ink);

    switch (level) {
      case 1:
        final tear = Paint()
          ..color = const Color(0xFF4FA3E0)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 * k
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(p(14, 20), p(14, 26), tear);
        canvas.drawLine(p(26, 20), p(26, 26), tear);
        canvas.drawPath(
          Path()
            ..moveTo(13 * k, 31 * k)
            ..quadraticBezierTo(20 * k, 26 * k, 27 * k, 31 * k),
          line,
        );
      case 2:
        canvas.drawPath(
          Path()
            ..moveTo(13 * k, 29 * k)
            ..quadraticBezierTo(20 * k, 24 * k, 27 * k, 29 * k),
          line,
        );
      case 3:
        canvas.drawLine(p(14, 27), p(26, 27), line);
      default:
        canvas.drawPath(
          Path()
            ..moveTo(13 * k, 25 * k)
            ..quadraticBezierTo(20 * k, 31 * k, 27 * k, 25 * k),
          line,
        );
    }
  }

  @override
  bool shouldRepaint(_FacePainter old) => old.level != level;
}

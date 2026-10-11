import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/paint_utils.dart';

class _Blob {
  const _Blob(this.color, this.points);
  final Color color;
  final List<Offset> points;
}

/// Globe berputar + pesawat emas yang mengorbit dengan jejak putus-putus.
/// Koordinat digambar pada kanvas 240 x 240 lalu diskalakan.
class GlobePainter extends CustomPainter {
  GlobePainter({
    required this.intro,
    required this.orbitFade,
    required this.orbit,
    required this.scroll,
  }) : super(repaint: Listenable.merge([intro, orbitFade, orbit, scroll]));

  final Animation<double> intro;
  final Animation<double> orbitFade;
  final Animation<double> orbit;
  final Animation<double> scroll;

  static const double _period = 248;
  static const _blobs = <_Blob>[
    _Blob(AppColors.teal,
        [Offset(20, 90), Offset(48, 74), Offset(68, 98), Offset(52, 130), Offset(18, 122)]),
    _Blob(AppColors.lightTeal,
        [Offset(100, 120), Offset(124, 108), Offset(142, 140), Offset(106, 168), Offset(88, 138)]),
    _Blob(AppColors.teal,
        [Offset(170, 80), Offset(196, 66), Offset(212, 90), Offset(184, 118), Offset(160, 98)]),
    _Blob(AppColors.lightTeal,
        [Offset(205, 140), Offset(224, 134), Offset(234, 156), Offset(206, 172), Offset(196, 150)]),
  ];

  /// Titik-titik dipakai sebagai kontrol kurva sehingga bentuknya organik.
  Path _blob(List<Offset> p) {
    Offset mid(Offset a, Offset b) => Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
    final n = p.length;
    final start = mid(p[n - 1], p[0]);
    final path = Path()..moveTo(start.dx, start.dy);
    for (var i = 0; i < n; i++) {
      final m = mid(p[i], p[(i + 1) % n]);
      path.quadraticBezierTo(p[i].dx, p[i].dy, m.dx, m.dy);
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 240);
    const c = Offset(120, 120);
    const r = 62.0;

    final introT = intro.value;
    final alpha = alphaOf(introT);
    final scale = 0.6 + 0.4 * introT.clamp(0.0, 1.2);

    // Globe
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(scale);
    canvas.translate(-c.dx, -c.dy);
    canvas.drawCircle(c, r, Paint()..color = AppColors.ink.withAlpha(alpha));

    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)));
    final dx = -scroll.value * _period;
    for (final offset in const [0.0, _period]) {
      canvas.save();
      canvas.translate(dx + offset, 0);
      for (final b in _blobs) {
        canvas.drawPath(_blob(b.points), Paint()..color = b.color.withAlpha(alpha));
      }
      canvas.restore();
    }
    canvas.restore();

    canvas.drawArc(
      Rect.fromCircle(center: c, radius: 48),
      -2.6,
      0.75,
      false,
      Paint()
        ..color = Colors.white.withAlpha((alpha * .3).round())
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();

    // Orbit + pesawat
    final fade = orbitFade.value.clamp(0.0, 1.0);
    if (fade > 0) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(orbit.value * 2 * math.pi);
      canvas.translate(-c.dx, -c.dy);

      // Jejak di belakang pesawat (240 derajat berlawanan arah jarum jam)
      final trail = Path()
        ..addArc(Rect.fromCircle(center: c, radius: 88), -math.pi / 2, -4 * math.pi / 3);
      drawDashed(
        canvas,
        trail,
        Paint()
          ..color = AppColors.ink.withAlpha(alphaOf(.75 * fade))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );

      canvas.translate(120, 32);
      drawPlane(canvas, opacity: fade);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(GlobePainter oldDelegate) => false;
}

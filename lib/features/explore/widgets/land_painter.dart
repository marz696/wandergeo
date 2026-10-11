import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/paint_utils.dart';
import 'map_geometry.dart';

/// Menggambar kisi tipis, daratan (dengan bayangan), dan garis putus-putus
/// dari posisi pengguna ke negara yang dipilih.
class LandPainter extends CustomPainter {
  LandPainter({
    required this.geometry,
    required this.reveal,
    this.user,
    this.target,
  });

  final MapGeometry geometry;
  final double reveal; // 0..1, animasi muncul
  final Offset? user;
  final Offset? target;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = Colors.white.withOpacity(.6 * reveal)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    for (var i = 1; i < 6; i++) {
      final x = size.width * i / 6;
      drawDashed(canvas, Path()..moveTo(x, 0)..lineTo(x, size.height), grid,
          dash: 3, gap: 7);
    }
    for (var i = 1; i < 5; i++) {
      final y = size.height * i / 5;
      drawDashed(canvas, Path()..moveTo(0, y)..lineTo(size.width, y), grid,
          dash: 3, gap: 7);
    }

    for (final poly in geometry.land) {
      final path = _smooth([for (final p in poly) geometry.designToLocal(p, size)]);
      canvas.drawPath(
        path.shift(const Offset(0, 3)),
        Paint()
          ..color = AppColors.mountainMid.withOpacity(.2 * reveal)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.drawPath(
        path,
        Paint()..color = const Color(0xFFF7FBFD).withOpacity(reveal),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = AppColors.mountainFar.withOpacity(reveal)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeJoin = StrokeJoin.round,
      );
    }

    if (user != null && target != null) {
      final u = user!;
      final t = target!;
      final mid = Offset((u.dx + t.dx) / 2, (u.dy + t.dy) / 2);
      final lift = (t - u).distance * .25;
      final route = Path()
        ..moveTo(u.dx, u.dy)
        ..quadraticBezierTo(mid.dx, mid.dy - lift, t.dx, t.dy);
      drawDashed(
        canvas,
        route,
        Paint()
          ..color = AppColors.goldDeep.withOpacity(reveal)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
        dash: 6,
        gap: 6,
      );
    }
  }

  /// Membulatkan sudut poligon lewat titik tengah sisi.
  Path _smooth(List<Offset> q) {
    Offset mid(Offset a, Offset b) => Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
    final n = q.length;
    final start = mid(q[n - 1], q[0]);
    final path = Path()..moveTo(start.dx, start.dy);
    for (var i = 0; i < n; i++) {
      final c = q[i];
      final m = mid(c, q[(i + 1) % n]);
      path.quadraticBezierTo(c.dx, c.dy, m.dx, m.dy);
    }
    return path..close();
  }

  @override
  bool shouldRepaint(LandPainter old) =>
      old.reveal != reveal ||
      old.user != user ||
      old.target != target ||
      old.geometry != geometry;
}

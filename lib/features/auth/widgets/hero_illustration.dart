import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/paint_utils.dart';

/// Ilustrasi petualang di bagian atas halaman login.
/// [enter] (0..1) mengatur animasi masuk: gunung naik bergantian.
/// Pesawat dan awan bergerak terus (loop internal).
///
/// [scale] = skala gambar (1 = lebar desain 390). Bila lebih kecil dari
/// lebar layar / 390, sisi kiri-kanan diisi perpanjangan gunung, dan jalur
/// pesawat diturunkan agar tidak tertutup status bar ([topInset]).
class HeroIllustration extends StatefulWidget {
  const HeroIllustration({
    super.key,
    required this.enter,
    required this.scale,
    this.topInset = 0,
  });

  final Animation<double> enter;
  final double scale;
  final double topInset;

  @override
  State<HeroIllustration> createState() => _HeroIllustrationState();
}

class _HeroIllustrationState extends State<HeroIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop =
      AnimationController(vsync: this, duration: const Duration(seconds: 9))
        ..repeat();

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Ilustrasi petualang dengan ransel menuju penanda lokasi '
          'di antara pegunungan',
      child: LayoutBuilder(
        builder: (_, c) => SizedBox(
          width: c.maxWidth,
          height: 400 * widget.scale,
          child: CustomPaint(
            painter: _HeroPainter(
              enter: widget.enter,
              loop: _loop,
              scale: widget.scale,
              topInset: widget.topInset,
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroPainter extends CustomPainter {
  _HeroPainter({
    required this.enter,
    required this.loop,
    required this.scale,
    required this.topInset,
  }) : super(repaint: Listenable.merge([enter, loop]));

  final Animation<double> enter;
  final Animation<double> loop;
  final double scale;
  final double topInset;

  double _p(double a, double b) =>
      Interval(a, b, curve: Curves.easeOutCubic).transform(enter.value);

  Paint _fill(Color c, [double o = 1]) =>
      Paint()..color = c.withAlpha(alphaOf(o));

  Paint _stroke(Color c, double w, [double o = 1]) => Paint()
    ..color = c.withAlpha(alphaOf(o))
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  void _layer(Canvas canvas, double t, VoidCallback draw) {
    canvas.save();
    canvas.translate(0, (1 - t) * 60);
    draw();
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(scale);
    // Kelebihan lebar (satuan desain) di tiap sisi bila skala < lebar/390.
    final extra = math.max(0.0, (size.width / scale - 390) / 2);
    canvas.translate(extra, 0);
    final sky = _p(0, .3);

    // Matahari
    canvas.drawCircle(const Offset(318, 96), 44, _fill(const Color(0xFFF5D060), sky));

    // Awan (bergeser pelan)
    final drift = (math.sin(loop.value * 2 * math.pi) + 1) / 2 * 26;
    final cloud = _fill(Colors.white, .9 * sky);
    for (final o in const [
      [70.0, 120.0, 68.0, 24.0],
      [96.0, 112.0, 44.0, 24.0],
      [240.0, 64.0, 56.0, 20.0],
    ]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(o[0] + drift, o[1]), width: o[2], height: o[3]),
        cloud,
      );
    }

    // Pesawat melintas dengan jejak putus-putus
    final laneY = math.max(60.0, (topInset + 18) / scale);
    final px = -extra - 20 + loop.value * (390 + 2 * extra + 90);
    drawDashed(
      canvas,
      Path()
        ..moveTo(px - 70, laneY)
        ..lineTo(px - 6, laneY),
      _stroke(AppColors.ink, 1.5, sky),
      dash: 4,
      gap: 4,
    );
    canvas.save();
    canvas.translate(px + 12, laneY);
    drawPlane(canvas, opacity: sky);
    canvas.restore();

    // Gunung: tiga lapis naik bergantian
    _layer(canvas, _p(.08, .48), () {
      canvas.drawPath(
        Path()
          ..moveTo(-400, 290)
          ..lineTo(0, 290)
          ..lineTo(70, 200)
          ..lineTo(130, 262)
          ..lineTo(200, 168)
          ..lineTo(290, 272)
          ..lineTo(390, 214)
          ..lineTo(800, 214)
          ..lineTo(800, 400)
          ..lineTo(-400, 400)
          ..close(),
        _fill(AppColors.mountainFar, _p(.08, .48)),
      );
    });
    _layer(canvas, _p(.15, .55), () {
      canvas.drawPath(
        Path()
          ..moveTo(-400, 335)
          ..lineTo(0, 335)
          ..lineTo(90, 250)
          ..lineTo(170, 322)
          ..lineTo(262, 236)
          ..lineTo(390, 330)
          ..lineTo(800, 330)
          ..lineTo(800, 400)
          ..lineTo(-400, 400)
          ..close(),
        _fill(AppColors.mountainMid, _p(.15, .55)),
      );
    });
    _layer(canvas, _p(.22, .62), () {
      canvas.drawPath(
        Path()
          ..moveTo(-400, 372)
          ..lineTo(0, 372)
          ..quadraticBezierTo(120, 330, 230, 366)
          ..quadraticBezierTo(340, 402, 390, 350)
          ..lineTo(800, 350)
          ..lineTo(800, 400)
          ..lineTo(-400, 400)
          ..close(),
        _fill(AppColors.hill, _p(.22, .62)),
      );
    });

    // Penanda lokasi + petualang
    final fg = _p(.35, .75);
    _layer(canvas, fg, () => _drawFigure(canvas, fg));
  }

  void _drawFigure(Canvas canvas, double o) {
    // Tiang + pin
    canvas.drawRect(const Rect.fromLTWH(297, 216, 6, 160), _fill(AppColors.ink, o));
    final pin = Path()
      ..moveTo(300, 150)
      ..cubicTo(286, 150, 276, 160, 276, 174)
      ..cubicTo(276, 192, 300, 216, 300, 216)
      ..cubicTo(300, 216, 324, 192, 324, 174)
      ..cubicTo(324, 160, 314, 150, 300, 150)
      ..close();
    canvas.drawPath(pin, _fill(AppColors.gold, o));
    canvas.drawPath(pin, _stroke(AppColors.ink, 3, o));
    canvas.drawCircle(const Offset(300, 174), 8, _fill(Colors.white, o));

    RRect rr(double x, double y, double w, double h, double r) =>
        RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r));

    // Kaki, badan, leher, kepala
    canvas.drawRRect(rr(137, 334, 11, 40, 4), _fill(AppColors.deepNavy, o));
    canvas.drawRRect(rr(152, 334, 11, 40, 4), _fill(AppColors.deepNavy, o));
    canvas.drawRRect(rr(130, 282, 40, 58, 16), _fill(AppColors.teal, o));
    canvas.drawRect(const Rect.fromLTWH(145, 274, 10, 10), _fill(AppColors.skin, o));
    canvas.drawCircle(const Offset(150, 266), 15, _fill(AppColors.ink, o));

    // Ransel
    canvas.drawRRect(rr(133, 288, 34, 38, 8), _fill(AppColors.gold, o));
    canvas.drawRRect(rr(133, 288, 34, 38, 8), _stroke(AppColors.ink, 2, o));
    canvas.drawRRect(rr(139, 308, 22, 12, 4), _fill(AppColors.goldDeep, o));

    // Lengan menunjuk ke penanda
    canvas.drawLine(const Offset(168, 296), const Offset(204, 286), _stroke(AppColors.teal, 9, o));
    canvas.drawCircle(const Offset(207, 285), 5.5, _fill(AppColors.skin, o));

    // Koper
    canvas.drawRRect(rr(178, 340, 26, 34, 5), _fill(AppColors.ink, o));
    canvas.drawPath(
      Path()
        ..moveTo(185, 340)
        ..lineTo(185, 324)
        ..lineTo(197, 324)
        ..lineTo(197, 340),
      _stroke(AppColors.ink, 3, o),
    );
  }

  @override
  bool shouldRepaint(_HeroPainter old) =>
      old.scale != scale || old.topInset != topInset;
}

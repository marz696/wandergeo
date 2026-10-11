import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Logo WanderGeo: huruf W dari satu garis di dalam cincin orbit yang
/// terbuka; ujung W mengarah ke titik emas (tujuan perjalanan).
/// Dengan [animate] = true: cincin tergambar, W tergambar, titik emas pop, riak.
class WanderGeoLogo extends StatefulWidget {
  const WanderGeoLogo({
    super.key,
    this.size = 96,
    this.ringColor = AppColors.ink,
    this.wColor = AppColors.ink,
    this.dotColor = AppColors.gold,
    this.animate = false,
  });

  /// Versi untuk latar gelap.
  const WanderGeoLogo.onDark({super.key, this.size = 96, this.animate = false})
      : ringColor = AppColors.background,
        wColor = AppColors.background,
        dotColor = AppColors.gold;

  final double size;
  final Color ringColor;
  final Color wColor;
  final Color dotColor;
  final bool animate;

  @override
  State<WanderGeoLogo> createState() => _WanderGeoLogoState();
}

class _WanderGeoLogoState extends State<WanderGeoLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _c.forward();
    } else {
      _c.value = 1;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Logo WanderGeo',
      child: CustomPaint(
        size: Size.square(widget.size),
        painter: _LogoPainter(
          _c,
          widget.ringColor,
          widget.wColor,
          widget.dotColor,
          showRipple: widget.animate,
        ),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter(this.t, this.ring, this.w, this.dot, {required this.showRipple})
      : super(repaint: t);

  final Animation<double> t;
  final Color ring;
  final Color w;
  final Color dot;
  final bool showRipple;

  double _iv(double a, double b, Curve c) =>
      Interval(a, b, curve: c).transform(t.value);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 96);
    const dotAt = Offset(81.5, 26.2);

    // Cincin orbit (terbuka 18%)
    final ringT = _iv(.0625, .406, Curves.easeOut);
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(48, 48), radius: 40),
      0,
      2 * math.pi * .82 * ringT,
      false,
      Paint()
        ..color = ring
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    // Huruf W
    final wT = _iv(.28, .5625, Curves.easeOut);
    final wPath = Path()
      ..moveTo(27, 37)
      ..lineTo(37.5, 62)
      ..lineTo(48, 44)
      ..lineTo(58.5, 62)
      ..lineTo(69, 37);
    final wPaint = Paint()
      ..color = w
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final m in wPath.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * wT), wPaint);
    }

    // Titik emas: pop 0 -> 1.6 -> 1
    final p = _iv(.53, .69, Curves.easeOut);
    final pop = p < .6 ? (p / .6) * 1.6 : 1.6 - .6 * ((p - .6) / .4);
    canvas.drawCircle(dotAt, 5 * pop, Paint()..color = dot);

    // Riak di sekitar titik
    if (showRipple) {
      final r = _iv(.69, 1, Curves.easeOut);
      if (r > 0 && r < 1) {
        canvas.drawCircle(
          dotAt,
          5 * (.4 + 2.2 * r),
          Paint()
            ..color = dot.withAlpha((.8 * (1 - r) * 255).round())
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_LogoPainter old) =>
      old.ring != ring || old.w != w || old.dot != dot;
}

/// Tulisan WANDERGEO: kapital, jarak huruf lebar, "GEO" beraksen.
class WanderGeoWordmark extends StatelessWidget {
  const WanderGeoWordmark({
    super.key,
    this.size = 28,
    this.color = AppColors.ink,
    this.accent = AppColors.goldDark,
  });

  /// Versi untuk latar gelap.
  const WanderGeoWordmark.onDark({super.key, this.size = 28})
      : color = AppColors.background,
        accent = AppColors.gold;

  final double size;
  final Color color;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: AppTheme.heading(size, color: color, weight: FontWeight.w600)
            .copyWith(letterSpacing: size * .24),
        children: [
          const TextSpan(text: 'WANDER'),
          TextSpan(text: 'GEO', style: TextStyle(color: accent)),
        ],
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/round_icon_button.dart';

/// Baris atas halaman misi: tombol kembali/tutup, judul, aksi di kanan.
class MissionTopBar extends StatelessWidget {
  const MissionTopBar({
    super.key,
    required this.title,
    this.subtitle,
    required this.onBack,
    this.icon = Icons.arrow_back_rounded,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onBack;
  final IconData icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        RoundIconButton(icon: icon, label: 'Kembali', onTap: onBack),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTheme.heading(22)),
              if (subtitle != null)
                Text(subtitle!,
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.muted)),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class CoinChip extends StatelessWidget {
  const CoinChip({super.key, required this.coins});

  final int coins;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: AppColors.ink.withOpacity(.15), blurRadius: 8),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.monetization_on_rounded,
              size: 20, color: AppColors.gold),
          const SizedBox(width: 5),
          Text('$coins',
              style: const TextStyle(
                  fontWeight: FontWeight.w800, color: AppColors.goldDark)),
        ],
      ),
    );
  }
}

/// Cincin progres (0..1) dengan konten di tengah.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    this.size = 64,
    this.stroke = 7,
    this.color = AppColors.gold,
    this.track = const Color(0x40FFFFFF),
    this.child,
  });

  final double value;
  final double size;
  final double stroke;
  final Color color;
  final Color track;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(value.clamp(0, 1).toDouble(), stroke, color, track),
        child: Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value, this.stroke, this.color, this.track);

  final double value;
  final double stroke;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = rect.deflate(stroke / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(r, 0, math.pi * 2, false, base..color = track);
    if (value > 0) {
      canvas.drawArc(r, -math.pi / 2, math.pi * 2 * value, false, base..color = color);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color || old.track != track;
}

/// Stempel paspor bundar bertuliskan kode & nama negara.
class StampBadge extends StatelessWidget {
  const StampBadge({super.key, required this.code, required this.name, this.size = 128});

  final String code;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Stempel $name',
      child: CustomPaint(
        size: Size.square(size),
        painter: _StampPainter(code, name.toUpperCase()),
      ),
    );
  }
}

class _StampPainter extends CustomPainter {
  _StampPainter(this.code, this.name);

  final String code;
  final String name;
  static const _red = Color(0xFFC8453B);

  void _text(Canvas c, String t, Offset center, double fs, FontWeight w, {double ls = 0}) {
    final tp = TextPainter(
      text: TextSpan(
        text: t,
        style: TextStyle(color: _red, fontSize: fs, fontWeight: w, letterSpacing: ls),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
  }

  void _arcText(Canvas c, String text, Offset center, double radius, double fs) {
    final step = (2 * math.pi) / text.length;
    for (var i = 0; i < text.length; i++) {
      final a = -math.pi / 2 + step * i;
      c.save();
      c.translate(center.dx + radius * math.cos(a), center.dy + radius * math.sin(a));
      c.rotate(a + math.pi / 2);
      final tp = TextPainter(
        text: TextSpan(
          text: text[i],
          style: TextStyle(color: _red, fontSize: fs, fontWeight: FontWeight.w800),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(c, Offset(-tp.width / 2, -tp.height / 2));
      c.restore();
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final s = size.width / 128;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..color = _red
      ..strokeWidth = 4 * s;
    canvas.drawCircle(c, 60 * s, ring);
    ring
      ..strokeWidth = 1.4 * s
      ..color = _red.withOpacity(.8);
    canvas.drawCircle(c, 34 * s, ring);
    _arcText(canvas, 'WANDERGEO · PASPOR DIGITAL · ', c, 47 * s, 9 * s);
    _text(canvas, code, c + Offset(0, -4 * s), 30 * s, FontWeight.w800);
    _text(canvas, name.length > 12 ? name.substring(0, 12) : name,
        c + Offset(0, 19 * s), 8.5 * s, FontWeight.w700, ls: 1.2);
  }

  @override
  bool shouldRepaint(_StampPainter old) => old.code != code || old.name != name;
}

/// Ikon + warna kartu budaya berdasarkan kolom `icon` di database.
({IconData icon, List<Color> colors}) cultureVisual(String key) {
  switch (key) {
    case 'drink':
      return (icon: Icons.local_cafe_rounded, colors: const [Color(0xFF8E5B3C), Color(0xFF4E2F1C)]);
    case 'dress':
      return (icon: Icons.checkroom_rounded, colors: const [Color(0xFFE3A92B), Color(0xFFC8453B)]);
    case 'music':
      return (icon: Icons.music_note_rounded, colors: const [Color(0xFF6C5CE7), Color(0xFF4834B8)]);
    case 'dance':
    case 'theatre':
      return (icon: Icons.theater_comedy_rounded, colors: const [Color(0xFF12304A), Color(0xFF0F7C8A)]);
    case 'temple':
      return (icon: Icons.account_balance_rounded, colors: const [Color(0xFFB8860B), Color(0xFF6B4F0A)]);
    case 'festival':
      return (icon: Icons.celebration_rounded, colors: const [Color(0xFFE05297), Color(0xFF8E2DE2)]);
    case 'craft':
      return (icon: Icons.palette_rounded, colors: const [Color(0xFF6C5CE7), Color(0xFFE05297)]);
    case 'landmark':
      return (icon: Icons.location_city_rounded, colors: const [Color(0xFF0F7C8A), Color(0xFF12304A)]);
    case 'sport':
      return (icon: Icons.sports_martial_arts_rounded, colors: const [Color(0xFFC8453B), Color(0xFF7A1F18)]);
    case 'vehicle':
      return (icon: Icons.directions_bus_rounded, colors: const [Color(0xFF2E9E6B), Color(0xFF0F7C8A)]);
    case 'greeting':
      return (icon: Icons.back_hand_rounded, colors: const [Color(0xFFF2994A), Color(0xFFC8453B)]);
    case 'history':
      return (icon: Icons.history_edu_rounded, colors: const [Color(0xFF4A5B6C), Color(0xFF12304A)]);
    case 'food':
    default:
      return (icon: Icons.ramen_dining_rounded, colors: const [Color(0xFF2E9E6B), Color(0xFF0F7C8A)]);
  }
}

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../mission/widgets/mission_ui.dart';
import '../models/passport_models.dart';
import '../passport_format.dart';
import 'passport_ui.dart';

/// Sampul paspor: nama, status verifikasi rantai, progres, dan ringkasan.
class PassportHero extends StatelessWidget {
  const PassportHero({required this.name, required this.data, required this.loading});

  final String name;
  final PassportData? data;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final d = data;
    final valid = d?.valid;
    final stamps = d?.stamps ?? 0;
    final total = d?.totalCountries ?? 0;
    final score = d?.blocks
            .where((b) => !b.isGenesis)
            .fold<int>(0, (s, b) => s + b.score) ??
        0;
    final lastHash =
        (d != null && d.blocks.isNotEmpty) ? d.blocks.last.hash : null;

    final tone = valid == null
        ? Colors.white.withOpacity(.7)
        : valid
            ? AppColors.success
            : const Color(0xFFFFB4AB);
    final label = loading && d == null
        ? 'Memverifikasi…'
        : valid == null
            ? 'Belum terverifikasi'
            : valid
                ? 'Rantai valid'
                : 'Blok #${d!.brokenAt} tidak cocok';

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.ink,
          boxShadow: passportCardShadow,
        ),
        child: CustomPaint(
          painter: _RingsPainter(),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PASPOR AGEN',
                            style: TextStyle(
                              color: AppColors.gold,
                              fontSize: 12,
                              letterSpacing: 2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.heading(22, color: Colors.white),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(.10),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  valid == false
                                      ? Icons.gpp_bad_rounded
                                      : Icons.verified_rounded,
                                  color: tone,
                                  size: 17,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    label,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    TweenAnimationBuilder<double>(
                      tween: Tween(
                        begin: 0,
                        end: total == 0 ? 0 : stamps / total,
                      ),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, __) => ProgressRing(
                        value: v,
                        size: 78,
                        stroke: 5,
                        track: Colors.white.withOpacity(.18),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$stamps/$total',
                              style: AppTheme.heading(16, color: Colors.white),
                            ),
                            Text(
                              'negara',
                              style: TextStyle(
                                color: Colors.white.withOpacity(.6),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(height: 1, color: Colors.white.withOpacity(.12)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _HeroStat(label: 'Skor total', value: '$score')),
                    Expanded(
                      child: _HeroStat(
                        label: 'Jumlah blok',
                        value: '${d?.blocks.length ?? 0}',
                      ),
                    ),
                  ],
                ),
                if (lastHash != null && lastHash.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    'HASH  ${passportShortHash(lastHash).toUpperCase()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(.38),
                      fontFamily: 'monospace',
                      fontSize: 11.5,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(.6), fontSize: 11.5),
        ),
        const SizedBox(height: 2),
        Text(value, style: AppTheme.heading(18, color: Colors.white)),
      ],
    );
  }
}

/// Lingkaran konsentris tipis sebagai tekstur latar (bukan warna).
class _RingsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withOpacity(.06);
    final c = Offset(size.width * .92, -size.height * .1);
    for (var r = 40.0; r < size.width; r += 34) {
      canvas.drawCircle(c, r, p);
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) => false;
}

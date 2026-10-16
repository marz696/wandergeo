import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/paint_utils.dart';
import '../../mission/widgets/mission_ui.dart';
import '../models/passport_models.dart';
import '../passport_format.dart';
import 'passport_ui.dart';

/// Matriks abu-abu untuk stempel yang tidak valid (seperti stempel dibatalkan).
const ColorFilter _greyscale = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0, 0, 0, 1, 0,
]);

class StampCard extends StatelessWidget {
  const StampCard({
    required this.block,
    required this.tilt,
    required this.onTap,
  });

  final PassportBlock block;
  final double tilt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ok = block.valid;
    final code = block.countryCode ?? '-';
    final name = block.countryName ?? code;

    Widget stamp = Transform.rotate(
      angle: tilt,
      child: StampBadge(code: code, name: name, size: 96),
    );
    if (!ok) {
      // Stempel yang rantainya rusak tampil pudar dan abu-abu (seperti dibatalkan).
      stamp = Opacity(
        opacity: .4,
        child: ColorFiltered(colorFilter: _greyscale, child: stamp),
      );
    }

    return Semantics(
      button: true,
      excludeSemantics: true,
      onTap: onTap,
      label: 'Stempel $name, skor ${block.score}, '
          '${ok ? 'terverifikasi' : 'tidak cocok'}',
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: ok ? AppColors.border : AppColors.error.withOpacity(.6),
            width: ok ? 1 : 1.3,
          ),
          boxShadow: passportCardShadow,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(21),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.field,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '#${block.index}',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        ok ? Icons.verified_rounded : Icons.gpp_bad_rounded,
                        size: 17,
                        color: ok ? AppColors.teal : AppColors.error,
                      ),
                    ],
                  ),
                  Expanded(
                    child: Center(child: FittedBox(child: stamp)),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      PassportFlag(url: block.flagUrl, size: 16),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.heading(14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          passportDate(block.timestamp),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.hint, fontSize: 12),
                        ),
                      ),
                      const Icon(Icons.stars_rounded,
                          size: 14, color: AppColors.hint),
                      const SizedBox(width: 3),
                      Text(
                        '${block.score}',
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Slot kosong untuk negara yang belum diselesaikan.
class EmptyStampSlot extends StatelessWidget {
  const EmptyStampSlot();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBoxPainter(AppColors.hint.withOpacity(.4)),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.sea.withOpacity(.45),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline_rounded,
                size: 24, color: AppColors.hint.withOpacity(.7)),
            const SizedBox(height: 8),
            const Text(
              'Belum didapat',
              style: TextStyle(color: AppColors.hint, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedBoxPainter extends CustomPainter {
  _DashedBoxPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(22),
    ).deflate(.75);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = color;
    drawDashed(canvas, Path()..addRRect(rrect), paint, dash: 6, gap: 5);
  }

  @override
  bool shouldRepaint(_DashedBoxPainter old) => old.color != color;
}


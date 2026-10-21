import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Bingkai bidik untuk keadaan kosong: empat sudut teal dan tiga garis teks samar.
class ViewfinderPainter extends CustomPainter {
  const ViewfinderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final bracket = Paint()
      ..color = AppColors.teal
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    const inset = 2.0;
    const len = 22.0;
    final l = inset, t = inset;
    final r = size.width - inset, b = size.height - inset;

    final path = Path()
      ..moveTo(l, t + len)
      ..lineTo(l, t)
      ..lineTo(l + len, t)
      ..moveTo(r - len, t)
      ..lineTo(r, t)
      ..lineTo(r, t + len)
      ..moveTo(r, b - len)
      ..lineTo(r, b)
      ..lineTo(r - len, b)
      ..moveTo(l + len, b)
      ..lineTo(l, b)
      ..lineTo(l, b - len);
    canvas.drawPath(path, bracket);

    final line = Paint()..color = AppColors.ink.withValues(alpha: .14);
    const widths = [.52, .68, .38];
    for (var i = 0; i < widths.length; i++) {
      final w = size.width * widths[i];
      final top = size.height * .30 + i * 16.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH((size.width - w) / 2, top, w, 7),
          const Radius.circular(3.5),
        ),
        line,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Lapisan di atas foto: kotak tiap blok teks, sorotan pada blok yang dipilih,
/// dan garis pindai saat foto sedang dibaca.
class ScanOverlayPainter extends CustomPainter {
  const ScanOverlayPainter({
    required this.imageSize,
    required this.boxes,
    required this.selected,
    required this.scanning,
    required this.progress,
  });

  /// Ukuran foto asli (piksel), dasar koordinat kotak dari ML Kit.
  final Size imageSize;
  final List<Rect> boxes;
  final int? selected;
  final bool scanning;
  final double progress;

  Rect _scaled(Rect r, Size size) {
    final sx = size.width / imageSize.width;
    final sy = size.height / imageSize.height;
    return Rect.fromLTRB(r.left * sx, r.top * sy, r.right * sx, r.bottom * sy)
        .inflate(3);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (imageSize.width <= 0 || imageSize.height <= 0) return;

    final sel = selected;
    final hasSel = sel != null && sel >= 0 && sel < boxes.length;

    if (hasSel) {
      // Redupkan seluruh foto kecuali blok yang dipilih.
      final hole = _scaled(boxes[sel], size);
      final dim = Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()..addRRect(RRect.fromRectAndRadius(hole, const Radius.circular(6))),
      );
      canvas.drawPath(
        dim,
        Paint()..color = AppColors.ink.withValues(alpha: .38),
      );
    }

    for (var i = 0; i < boxes.length; i++) {
      final rr = RRect.fromRectAndRadius(
        _scaled(boxes[i], size),
        const Radius.circular(6),
      );
      if (hasSel && i == sel) {
        canvas.drawRRect(
          rr,
          Paint()
            ..color = AppColors.lightTeal
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
      } else {
        canvas.drawRRect(
          rr,
          Paint()
            ..color = Colors.white.withValues(alpha: hasSel ? .45 : .9)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4,
        );
      }
    }

    if (scanning) {
      final y = size.height * progress;
      canvas.drawRect(
        Rect.fromLTRB(0, y - 40, size.width, y),
        Paint()..color = AppColors.lightTeal.withValues(alpha: .12),
      );
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()
          ..color = AppColors.lightTeal
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ScanOverlayPainter old) =>
      old.progress != progress ||
      old.selected != selected ||
      old.scanning != scanning ||
      old.imageSize != imageSize ||
      old.boxes != boxes;
}

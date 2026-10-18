import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

const _tint = Color(0xFFE8EEF3);

/// Tanggal singkat, mis. "15 Okt 2026".
String feedbackDate(DateTime t) {
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
  return '${t.day} ${m[t.month - 1]} ${t.year}';
}

/// Label kecil di atas judul, mis. "KESAN & SARAN".
class FeedbackEyebrow extends StatelessWidget {
  const FeedbackEyebrow(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          color: AppColors.hint,
          fontSize: 11,
          letterSpacing: 1.5,
          fontWeight: FontWeight.w600,
        ),
      );
}

/// Tombol silang bulat (menutup halaman yang dibuka dari tab Kesan).
class CloseCircle extends StatelessWidget {
  const CloseCircle({super.key});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: 'Tutup',
        child: Material(
          color: _tint,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => Navigator.of(context).maybePop(),
            child: const SizedBox(
              width: 40,
              height: 40,
              child: Icon(Icons.close_rounded, size: 20, color: AppColors.muted),
            ),
          ),
        ),
      );
}

/// Chip pilihan. Terpilih = emas dengan garis emas, tidak terpilih = putih
/// dengan garis abu, supaya keduanya jelas terlihat di latar terang.
class TagChip extends StatelessWidget {
  const TagChip({super.key, required this.label, this.selected = false, this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? const Color(0xFFF9E3A3) : Colors.white,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? AppColors.gold : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: .4,
                color: selected ? AppColors.goldDark : AppColors.ink,
              ),
            ),
          ),
        ),
      );
}

/// Tombol utama pil berwarna teal; abu-teal pudar saat nonaktif.
class FeedbackButton extends StatelessWidget {
  const FeedbackButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 52,
        width: double.infinity,
        child: FilledButton(
          onPressed: loading ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.teal,
            // Nonaktif = abu-biru pekat (bukan teal pudar) supaya tetap terbaca.
            disabledBackgroundColor: loading ? AppColors.teal : AppColors.hint,
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white,
            shape: const StadiumBorder(),
          ),
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
        ),
      );
}

class FeedbackErrorCard extends StatelessWidget {
  const FeedbackErrorCard({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFCEBE9),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_rounded, color: AppColors.error),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(color: AppColors.ink))),
            TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
          ],
        ),
      );
}

class FeedbackEmptyCard extends StatelessWidget {
  const FeedbackEmptyCard(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(text, style: const TextStyle(color: AppColors.muted, height: 1.4)),
      );
}
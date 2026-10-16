import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';

final List<BoxShadow> passportCardShadow = [
  BoxShadow(
    color: AppColors.ink.withOpacity(.08),
    blurRadius: 18,
    offset: const Offset(0, 8),
  ),
];

class PassportSectionHeader extends StatelessWidget {
  const PassportSectionHeader({required this.title, this.badge});

  final String title;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: AppTheme.heading(17)),
        const Spacer(),
        if (badge != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.sea,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              badge!,
              style: const TextStyle(
                color: AppColors.teal,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }
}

/// Muncul pelan dari bawah; item yang lebih akhir sedikit lebih lambat.
class PassportReveal extends StatelessWidget {
  const PassportReveal({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 320 + math.min(index, 8) * 70),
      curve: Curves.easeOutCubic,
      builder: (_, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 14 * (1 - v)), child: c),
      ),
      child: child,
    );
  }
}

class _Pulse extends StatefulWidget {
  const _Pulse({required this.child});

  final Widget child;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: .5, end: 1)
          .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
      child: widget.child,
    );
  }
}

class PassportSkeleton extends StatelessWidget {
  const PassportSkeleton();

  @override
  Widget build(BuildContext context) {
    return _Pulse(
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: .86,
        children: [
          for (var i = 0; i < 4; i++)
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.sea,
                borderRadius: BorderRadius.circular(22),
              ),
            ),
        ],
      ),
    );
  }
}

class PassportFlag extends StatelessWidget {
  const PassportFlag({required this.url, this.size = 44});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback =
        Icon(Icons.flag_rounded, color: AppColors.teal, size: size * .6);
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * .22),
      child: SizedBox(
        width: size * 1.35,
        height: size,
        child: url == null
            ? ColoredBox(color: AppColors.sea, child: fallback)
            : Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    ColoredBox(color: AppColors.sea, child: fallback),
              ),
      ),
    );
  }
}

class PassportErrorCard extends StatelessWidget {
  const PassportErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.error.withOpacity(.25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_rounded, color: AppColors.error),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message,
                  style: const TextStyle(color: AppColors.ink, height: 1.35)),
            ),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(foregroundColor: AppColors.teal),
              child: const Text('Coba lagi'),
            ),
          ],
        ),
      );
}

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class NavItemData {
  const NavItemData({
    required this.icon,
    required this.label,
    required this.shortLabel,
    this.tint,
  });

  final IconData icon;
  final String label; // untuk aksesibilitas
  final String shortLabel; // tampil saat tab aktif
  final Color? tint; // warna ikon saat tidak aktif
}

/// Bottom navigation pill melayang. Tab aktif melebar (ikon + label, gradasi teal),
/// tab lain berupa ikon bulat.
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<NavItemData> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  static const double _dot = 48;
  static const double _gap = 6;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 0, 16, 12 + MediaQuery.of(context).padding.bottom),
      child: Container(
        height: 64,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white.withOpacity(.08)),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withOpacity(.4),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, box) {
            final activeW = (box.maxWidth - (items.length - 1) * (_dot + _gap))
                .clamp(_dot, double.infinity)
                .toDouble();
            return Row(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(width: _gap),
                  _NavButton(
                    item: items[i],
                    active: i == currentIndex,
                    activeWidth: activeW,
                    onTap: () => onTap(i),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.active,
    required this.activeWidth,
    required this.onTap,
  });

  final NavItemData item;
  final bool active;
  final double activeWidth;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      label: item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 340),
          curve: Curves.easeOutCubic,
          width: active ? activeWidth : FloatingNavBar._dot,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: active ? null : const Color(0xFF1B3A57),
            gradient: active
                ? const LinearGradient(
                    colors: [AppColors.teal, Color(0xFF0A5F6E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
          ),
          child: ClipRect(
            child: OverflowBox(
              minWidth: 0,
              maxWidth: activeWidth,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.icon,
                      size: 22,
                      color: active
                          ? Colors.white
                          : (item.tint ?? const Color(0xFFDCE5EB)),
                    ),
                    if (active) ...[
                      const SizedBox(width: 6),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOut,
                        builder: (_, v, child) =>
                            Opacity(opacity: v, child: child),
                        child: Text(
                          item.shortLabel,
                          maxLines: 1,
                          softWrap: false,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/country.dart';

/// Penanda negara di peta. Terbuka = berdenyut, terpilih = membesar + cincin emas,
/// tidak cocok filter = memudar.
class CountryMarker extends StatelessWidget {
  const CountryMarker({
    super.key,
    required this.country,
    required this.selected,
    required this.dimmed,
    required this.pulse,
    required this.onTap,
  });

  final Country country;
  final bool selected;
  final bool dimmed;
  final Animation<double> pulse;
  final VoidCallback onTap;

  Color get _bg => switch (country.status) {
        CountryStatus.selesai => AppColors.success,
        CountryStatus.terbuka => AppColors.teal,
        CountryStatus.terkunci => AppColors.border,
      };

  Widget get _icon => switch (country.status) {
        CountryStatus.selesai =>
          const Icon(Icons.check_rounded, size: 16, color: Colors.white),
        CountryStatus.terbuka =>
          const Icon(Icons.circle, size: 8, color: Colors.white),
        CountryStatus.terkunci =>
          const Icon(Icons.lock_rounded, size: 13, color: AppColors.muted),
      };

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${country.name}, ${country.statusLabel}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedOpacity(
          opacity: dimmed ? .28 : 1,
          duration: const Duration(milliseconds: 220),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 48,
                height: 44,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    if (country.status == CountryStatus.terbuka)
                      AnimatedBuilder(
                        animation: pulse,
                        builder: (_, __) {
                          final t = pulse.value;
                          return Container(
                            width: 28 + 24 * t,
                            height: 28 + 24 * t,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.gold.withOpacity((1 - t) * .8),
                                width: 2,
                              ),
                            ),
                          );
                        },
                      ),
                    AnimatedScale(
                      scale: selected ? 1.3 : 1,
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutBack,
                      child: Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _bg,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: selected
                                  ? AppColors.gold
                                  : Colors.black.withOpacity(.2),
                              blurRadius: selected ? 10 : 5,
                              spreadRadius: selected ? 3 : 0,
                            ),
                          ],
                        ),
                        child: _icon,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                country.code,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.deepNavy,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

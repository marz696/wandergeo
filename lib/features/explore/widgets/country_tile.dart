import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/geo_utils.dart';
import '../models/country.dart';

class CountryTile extends StatelessWidget {
  const CountryTile({
    super.key,
    required this.country,
    required this.onTap,
    this.distanceKm,
    this.recommended = false,
  });

  final Country country;
  final double? distanceKm;
  final bool recommended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = country;
    final locked = c.status == CountryStatus.terkunci;
    final sub = distanceKm == null
        ? c.capital
        : '${c.capital} · ${GeoUtils.formatKm(distanceKm!)}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: recommended
                ? AppColors.gold.withOpacity(.8)
                : AppColors.border,
            width: recommended ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: switch (c.status) {
                      CountryStatus.selesai => AppColors.success,
                      CountryStatus.terbuka => AppColors.teal,
                      CountryStatus.terkunci => AppColors.border,
                    },
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    c.code,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: locked ? AppColors.muted : Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (recommended) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFBEFD0),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.auto_awesome_rounded,
                                  size: 12, color: AppColors.goldDark),
                              SizedBox(width: 4),
                              Text(
                                'Rekomendasi AI',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.goldDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      Text(c.name, style: AppTheme.heading(15.5)),
                      const SizedBox(height: 2),
                      Text(
                        sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                Icon(
                  switch (c.status) {
                    CountryStatus.selesai => Icons.check_circle_rounded,
                    CountryStatus.terbuka => Icons.chevron_right_rounded,
                    CountryStatus.terkunci => Icons.lock_outline_rounded,
                  },
                  color: switch (c.status) {
                    CountryStatus.selesai => AppColors.success,
                    CountryStatus.terbuka => AppColors.teal,
                    CountryStatus.terkunci => AppColors.hint,
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

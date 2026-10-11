import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/geo_utils.dart';
import '../models/country.dart';
import 'country_photo.dart';

/// Kartu di carousel bawah peta.
class CountryCard extends StatelessWidget {
  const CountryCard({
    super.key,
    required this.country,
    required this.onTap,
    this.distanceKm,
    this.recommended = false,
    this.highlighted = false,
  });

  final Country country;
  final double? distanceKm;
  final bool recommended;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = country;
    final (statusText, statusColor) = switch (c.status) {
      CountryStatus.selesai => ('Selesai', AppColors.success),
      CountryStatus.terbuka => ('Terbuka · +75 koin', AppColors.goldDark),
      CountryStatus.terkunci => ('Terkunci', AppColors.muted),
    };
    final sub = distanceKm == null
        ? c.capital
        : '${c.capital} · ${GeoUtils.formatKm(distanceKm!)}';

    return Material(
      color: Colors.white,
      elevation: 6,
      shadowColor: AppColors.ink.withOpacity(.3),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(
          color: highlighted ? AppColors.gold : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            CountryPhoto(country: c, width: 96, height: 116),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (recommended) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFBEFD0),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_awesome_rounded,
                                size: 11, color: AppColors.goldDark),
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
                    Text(c.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.heading(17)),
                    const SizedBox(height: 2),
                    Text(
                      sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.muted),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

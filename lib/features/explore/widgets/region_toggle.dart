import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/country.dart';

/// Pengalih ASEAN / UK dengan indikator yang bergeser halus.
class RegionToggle extends StatelessWidget {
  const RegionToggle({super.key, required this.region, required this.onChanged});

  final CountryRegion region;
  final ValueChanged<CountryRegion> onChanged;

  @override
  Widget build(BuildContext context) {
    final asean = region == CountryRegion.asean;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: AppColors.ink.withOpacity(.14), blurRadius: 10),
        ],
      ),
      child: SizedBox(
        width: 132,
        height: 36,
        child: Stack(
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              alignment: asean ? Alignment.centerLeft : Alignment.centerRight,
              child: Container(
                width: 66,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
            Row(
              children: [
                _seg('ASEAN', asean, CountryRegion.asean),
                _seg('UK', !asean, CountryRegion.uk),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _seg(String label, bool active, CountryRegion value) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: active,
        label: 'Wilayah $label',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(value),
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: active ? Colors.white : AppColors.muted,
              ),
              child: Text(label),
            ),
          ),
        ),
      ),
    );
  }
}

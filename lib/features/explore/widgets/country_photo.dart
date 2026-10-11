import 'package:flutter/material.dart';

import '../../../core/services/wikipedia_service.dart';
import '../../../core/theme/app_colors.dart';
import '../models/country.dart';

/// Foto negara dari Wikipedia. Selama dimuat (atau bila gagal/offline)
/// tampil gradasi warna berdasarkan status + kode negara.
class CountryPhoto extends StatelessWidget {
  const CountryPhoto({
    super.key,
    required this.country,
    required this.width,
    required this.height,
    this.radius = 0,
  });

  final Country country;
  final double width;
  final double height;
  final double radius;

  List<Color> get _colors => switch (country.status) {
        CountryStatus.selesai => const [AppColors.success, AppColors.teal],
        CountryStatus.terbuka => const [AppColors.teal, AppColors.deepNavy],
        CountryStatus.terkunci => const [AppColors.hint, AppColors.muted],
      };

  @override
  Widget build(BuildContext context) {
    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            country.code,
            style: TextStyle(
              color: Colors.white.withOpacity(.85),
              fontWeight: FontWeight.w800,
              fontSize: height * .28,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: FutureBuilder<WikiInfo?>(
          future: WikipediaService.instance.info(country.code),
          builder: (context, snap) {
            final url = snap.data?.imageUrl;
            return Stack(
              fit: StackFit.expand,
              children: [
                fallback,
                if (url != null)
                  Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    frameBuilder: (context, child, frame, sync) => AnimatedOpacity(
                      opacity: frame == null ? 0 : 1,
                      duration: const Duration(milliseconds: 350),
                      child: child,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

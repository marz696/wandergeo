import 'package:flutter/material.dart';

import '../../../core/data/coin_prices.dart';
import '../../../core/services/weather_service.dart';
import '../../../core/services/wikipedia_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/geo_utils.dart';
import '../../../core/widgets/round_icon_button.dart';
import '../models/country.dart';
import 'country_photo.dart';

/// Panel detail negara yang muncul di atas bottom nav saat negara dipilih.
/// Ringkasan + foto dari Wikipedia, cuaca dari Open-Meteo. Tarik ke bawah
/// untuk menutup.
class CountryDetailPanel extends StatelessWidget {
  const CountryDetailPanel({
    super.key,
    required this.country,
    required this.distanceKm,
    required this.approximate,
    required this.onStart,
    required this.onTools,
    required this.onClose,
    required this.coins,
    required this.onBuyVisa,
    this.buyingVisa = false,
  });

  final Country country;
  final double? distanceKm;
  final bool approximate;
  final VoidCallback onStart;
  final VoidCallback onTools;
  final VoidCallback onClose;

  /// Saldo koin pengguna, untuk menentukan apakah Visa Cepat terjangkau.
  final int coins;

  /// Dipanggil saat pengguna menekan "Buka Visa" pada negara terkunci.
  final VoidCallback onBuyVisa;

  /// true selama permintaan pembelian visa berjalan.
  final bool buyingVisa;

  @override
  Widget build(BuildContext context) {
    final c = country;
    final locked = c.status == CountryStatus.terkunci;
    final done = c.status == CountryStatus.selesai;
    final visaPrice = visaCostFor(c.difficulty);
    final canAffordVisa = coins >= visaPrice;
    final (statusText, statusBg, statusFg) = switch (c.status) {
      CountryStatus.selesai => ('Selesai', AppColors.success, Colors.white),
      CountryStatus.terbuka => ('Terbuka', AppColors.gold, AppColors.ink),
      CountryStatus.terkunci => ('Terkunci', AppColors.border, AppColors.muted),
    };

    return GestureDetector(
      onVerticalDragEnd: (d) {
        if ((d.primaryVelocity ?? 0) > 250) onClose();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withOpacity(.25),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                CountryPhoto(country: c, width: 76, height: 76, radius: 20),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.name, style: AppTheme.heading(22)),
                      const SizedBox(height: 2),
                      Text(
                        '${c.capital} · ${c.language}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.muted),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 11, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: statusFg,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _chip(distanceKm == null
                      ? 'Jarak —'
                      : GeoUtils.formatKm(distanceKm!) +
                          (approximate ? ' (perkiraan)' : '')),
                  FutureBuilder<WeatherInfo?>(
                    future: WeatherService.instance.fetch(c.code, c.lat, c.lng),
                    builder: (context, snap) {
                      final text =
                          snap.connectionState == ConnectionState.waiting
                              ? 'Memuat cuaca…'
                              : snap.data?.text;
                      return text == null ? const SizedBox.shrink() : _chip(text);
                    },
                  ),
                  _chip(c.utcLabel),
                  _chip(c.currency),
                ],
              ),
            ),
            const SizedBox(height: 10),
            FutureBuilder<WikiInfo?>(
              future: WikipediaService.instance.info(c.code),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const _Skeleton();
                }
                final info = snap.data;
                if (info == null || info.summary.isEmpty) {
                  return const Text(
                    'Ringkasan belum tersedia. Periksa koneksi internet.',
                    style: TextStyle(fontSize: 13, color: AppColors.muted),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info.summary,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Sumber: Wikipedia',
                      style: TextStyle(fontSize: 11, color: AppColors.hint),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: FilledButton(
                      onPressed: locked
                          ? (buyingVisa ? null : onBuyVisa)
                          : onStart,
                      style: FilledButton.styleFrom(
                        backgroundColor: locked
                            ? (canAffordVisa ? AppColors.ink : AppColors.border)
                            : AppColors.gold,
                        foregroundColor: locked
                            ? (canAffordVisa ? Colors.white : AppColors.muted)
                            : AppColors.ink,
                        disabledBackgroundColor: AppColors.border,
                        disabledForegroundColor: AppColors.hint,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        textStyle: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      child: locked
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (buyingVisa)
                                  const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                else
                                  const Icon(Icons.airplane_ticket_rounded,
                                      size: 20),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Buka Visa · $visaPrice koin',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            )
                          : Text(done ? 'Main Lagi' : 'Mulai Misi'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                RoundIconButton(
                  icon: Icons.currency_exchange_rounded,
                  label: 'Alat Perjalanan',
                  size: 50,
                  elevated: false,
                  onTap: onTools,
                ),
              ],
            ),
            if (locked) ...[
              const SizedBox(height: 8),
              Text(
                canAffordVisa
                    ? 'Atau selesaikan negara lain agar ${c.name} terbuka gratis. '
                        'Koinmu: $coins.'
                    : 'Koinmu $coins, butuh $visaPrice. Kumpulkan koin dari misi, '
                        'atau selesaikan negara lain agar terbuka gratis.',
                style: const TextStyle(
                    fontSize: 11.5, height: 1.35, color: AppColors.muted),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(String text) => Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.sea,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.deepNavy,
          ),
        ),
      );
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    Widget bar(double w) => Container(
          width: w,
          height: 10,
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(5),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [bar(double.infinity), bar(double.infinity), bar(180)],
    );
  }
}
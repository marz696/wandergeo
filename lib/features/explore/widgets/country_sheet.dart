import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/geo_utils.dart';
import '../models/country.dart';

/// Bottom sheet detail negara: info singkat + daftar misi.
class CountrySheet {
  CountrySheet._();

  static Future<void> show(
    BuildContext context, {
    required Country country,
    required VoidCallback onStart,
    double? distanceKm,
    bool approximateLocation = false,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SheetBody(
        country: country,
        distanceKm: distanceKm,
        approximate: approximateLocation,
        onStart: onStart,
      ),
    );
  }
}

class _SheetBody extends StatelessWidget {
  const _SheetBody({
    required this.country,
    required this.distanceKm,
    required this.approximate,
    required this.onStart,
  });

  final Country country;
  final double? distanceKm;
  final bool approximate;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final c = country;
    final locked = c.status == CountryStatus.terkunci;
    final done = c.status == CountryStatus.selesai;
    final missions = [
      ('Trivia', '5 soal pilihan ganda', 20),
      ('Kuliner & Budaya', 'Kenali makanan dan tradisi', 30),
      ('Mini Game', 'Goyang HP untuk kumpulkan koin', 25),
    ];

    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, 20 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.deepNavy, AppColors.teal],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  c.code,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.name, style: AppTheme.heading(21)),
                    const SizedBox(height: 2),
                    Text(
                      '${c.capital} · ${c.language}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              _StatusChip(status: c.status),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _Info('Ibukota', c.capital, 'Pusat pemerintahan')),
              const SizedBox(width: 10),
              Expanded(
                child: _Info(
                  'Jarak (LBS)',
                  distanceKm == null ? '—' : GeoUtils.formatKm(distanceKm!),
                  approximate ? 'dari lokasi perkiraan' : 'dari posisimu',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _Info('Zona waktu', c.utcLabel, 'Waktu setempat')),
              const SizedBox(width: 10),
              Expanded(child: _Info('Mata uang', c.currency, 'Kode ISO 4217')),
            ],
          ),
          const SizedBox(height: 18),
          Text('Misi', style: AppTheme.heading(16)),
          const SizedBox(height: 4),
          for (final m in missions)
            _MissionRow(
              title: m.$1,
              subtitle: m.$2,
              coins: m.$3,
              locked: locked,
              done: done,
            ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: locked
                  ? null
                  : () {
                      Navigator.of(context).pop();
                      onStart();
                    },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.ink,
                disabledBackgroundColor: AppColors.border,
                disabledForegroundColor: AppColors.hint,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
                textStyle:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              child: Text(
                locked ? 'Terkunci' : (done ? 'Main Lagi' : 'Mulai Misi'),
              ),
            ),
          ),
          if (locked)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Center(
                child: Text(
                  'Selesaikan negara yang terbuka untuk membukanya.',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final CountryStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      CountryStatus.selesai => ('Selesai', AppColors.success, Colors.white),
      CountryStatus.terbuka => ('Terbuka', AppColors.gold, AppColors.ink),
      CountryStatus.terkunci => ('Terkunci', AppColors.border, AppColors.muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: fg),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info(this.label, this.value, this.sub);

  final String label;
  final String value;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted)),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          Text(sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: AppColors.hint)),
        ],
      ),
    );
  }
}

class _MissionRow extends StatelessWidget {
  const _MissionRow({
    required this.title,
    required this.subtitle,
    required this.coins,
    required this.locked,
    required this.done,
  });

  final String title;
  final String subtitle;
  final int coins;
  final bool locked;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: locked ? .5 : 1,
      child: Container(
        height: 58,
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.muted)),
                ],
              ),
            ),
            if (locked)
              const Icon(Icons.lock_outline_rounded,
                  size: 18, color: AppColors.hint)
            else if (done)
              const Text('Selesai',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.success))
            else
              Text('+$coins koin',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.goldDark)),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';

/// Hari Minggu terakhir pada bulan tertentu (UTC).
DateTime _lastSunday(int year, int month, int hourUtc) {
  final lastDay = DateTime.utc(year, month + 1, 0);
  final day = lastDay.subtract(Duration(days: lastDay.weekday % 7));
  return DateTime.utc(year, month, day.day, hourUtc);
}

/// London memakai BST (UTC+1) dari Minggu terakhir Maret 01:00 UTC sampai
/// Minggu terakhir Oktober 01:00 UTC.
bool isLondonBst(DateTime utc) {
  final start = _lastSunday(utc.year, 3, 1);
  final end = _lastSunday(utc.year, 10, 1);
  return !utc.isBefore(start) && utc.isBefore(end);
}

class _Zone {
  const _Zone(this.code, this.place, this.fixedHours);

  final String code;
  final String place;
  final int? fixedHours; // null = London (mengikuti BST)

  Duration offset(DateTime utc) {
    if (fixedHours != null) return Duration(hours: fixedHours!);
    return isLondonBst(utc) ? const Duration(hours: 1) : Duration.zero;
  }

  String utcLabel(DateTime utc) {
    if (fixedHours != null) return 'UTC+$fixedHours';
    return isLondonBst(utc) ? 'UTC+1 (BST)' : 'UTC+0 (GMT)';
  }
}

/// Konversi waktu WIB, WITA, WIT, dan London. Jam berjalan langsung;
/// "Atur jam" untuk mengonversi jam tertentu dari zona acuan.
class WorldTimeCard extends StatefulWidget {
  const WorldTimeCard({super.key});

  @override
  State<WorldTimeCard> createState() => _WorldTimeCardState();
}

class _WorldTimeCardState extends State<WorldTimeCard> {
  static const _zones = [
    _Zone('WIB', 'Jakarta', 7),
    _Zone('WITA', 'Makassar', 8),
    _Zone('WIT', 'Jayapura', 9),
    _Zone('London', 'Inggris Raya', null),
  ];
  static const _days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];

  Timer? _ticker;
  int _ref = 0; // zona acuan
  TimeOfDay? _custom; // null = jam sekarang

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_custom == null && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// Instan acuan dalam UTC.
  DateTime get _utc {
    final now = DateTime.now().toUtc();
    final custom = _custom;
    if (custom == null) return now;
    final zone = _zones[_ref];
    final localNow = now.add(zone.offset(now));
    final localCustom = DateTime.utc(
        localNow.year, localNow.month, localNow.day, custom.hour, custom.minute);
    return localCustom.subtract(zone.offset(now));
  }

  Future<void> _pickTime() async {
    final utc = _utc;
    final l = utc.add(_zones[_ref].offset(utc));
    final picked = await showTimePicker(
      context: context,
      initialTime: _custom ?? TimeOfDay(hour: l.hour, minute: l.minute),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _custom = picked);
  }

  void _setRef(int i) {
    if (i == _ref) return;
    HapticFeedback.selectionClick();
    final utc = _utc;
    setState(() {
      _ref = i;
      if (_custom != null) {
        // Pertahankan instan yang sama, tampilkan dalam zona acuan baru.
        final l = utc.add(_zones[i].offset(utc));
        _custom = TimeOfDay(hour: l.hour, minute: l.minute);
      }
    });
  }

  String _two(int v) => v.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final utc = _utc;
    final refLocal = utc.add(_zones[_ref].offset(utc));
    final live = _custom == null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Waktu Dunia', style: AppTheme.heading(17)),
          const SizedBox(height: 2),
          Text(
            live
                ? 'Jam sekarang · ketuk zona untuk menjadikannya acuan'
                : 'Jam acuan ${_two(_custom!.hour)}:${_two(_custom!.minute)} ${_zones[_ref].code}',
            style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _pickTime,
                icon: const Icon(Icons.schedule_rounded, size: 18),
                label: const Text('Atur jam'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.deepNavy,
                  side: const BorderSide(color: AppColors.border),
                  shape: const StadiumBorder(),
                ),
              ),
              if (!live) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => setState(() => _custom = null),
                  child: const Text('Kembali ke sekarang'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < _zones.length; i++) _row(i, utc, refLocal, live),
        ],
      ),
    );
  }

  Widget _row(int i, DateTime utc, DateTime refLocal, bool live) {
    final zone = _zones[i];
    final l = utc.add(zone.offset(utc));
    final diff = DateTime.utc(l.year, l.month, l.day)
        .difference(DateTime.utc(refLocal.year, refLocal.month, refLocal.day))
        .inDays;
    final dayText = diff == 0
        ? 'hari yang sama'
        : (diff > 0 ? (diff == 1 ? 'besok' : '+$diff hari') : (diff == -1 ? 'kemarin' : '$diff hari'));
    final isRef = i == _ref;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: isRef ? AppColors.sea : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: isRef ? AppColors.teal : AppColors.border,
            width: isRef ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          customBorder: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18)),
          onTap: () => _setRef(i),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(zone.code, style: AppTheme.heading(16)),
                          if (isRef) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.teal,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('Acuan',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800)),
                            ),
                          ],
                        ],
                      ),
                      Text('${zone.place} · ${zone.utcLabel(utc)}',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.muted)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${_two(l.hour)}:${_two(l.minute)}${live ? ':${_two(l.second)}' : ''}',
                      style: AppTheme.heading(22),
                    ),
                    Text(
                      '${_days[l.weekday - 1]}, ${l.day} ${_months[l.month - 1]} · $dayText',
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.muted),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

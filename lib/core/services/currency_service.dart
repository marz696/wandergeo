import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';

import '../data/currencies.dart';
import '../database/app_database.dart';

class RateTable {
  RateTable({
    required this.perUsd,
    required this.rateDate,
    required this.fetchedAt,
  });

  /// Jumlah mata uang X untuk 1 USD (USD sendiri = 1).
  final Map<String, double> perUsd;
  final String? rateDate;
  final DateTime fetchedAt;

  bool supports(String code) => perUsd.containsKey(code);

  /// Kurs 1 [from] dalam [to]; null bila salah satunya tidak tersedia.
  double? rate(String from, String to) {
    final f = perUsd[from];
    final t = perUsd[to];
    if (f == null || t == null || f == 0) return null;
    return t / f;
  }
}

enum RateStatus { loading, fresh, offline, unavailable }

/// Kurs dari Frankfurter v2 (gratis, tanpa API key), disimpan di SQLite
/// supaya tetap bisa dipakai tanpa internet. Satu permintaan mengambil semua
/// mata uang terhadap USD; konversi antar mata uang dihitung silang lewat USD.
class CurrencyService {
  CurrencyService._();

  static final CurrencyService instance = CurrencyService._();

  static const _maxAge = Duration(hours: 6);

  Future<(RateTable?, RateStatus)> load({bool force = false}) async {
    final cached = await _readCache();
    if (!force &&
        cached != null &&
        DateTime.now().difference(cached.fetchedAt) < _maxAge) {
      return (cached, RateStatus.fresh);
    }
    try {
      return (await _fetchAndSave(), RateStatus.fresh);
    } catch (_) {
      return cached != null
          ? (cached, RateStatus.offline)
          : (null, RateStatus.unavailable);
    }
  }

  Future<RateTable> _fetchAndSave() async {
    final quotes = kCurrencies.map((c) => c.code).where((c) => c != 'USD');
    final uri = Uri.https('api.frankfurter.dev', '/v2/rates', {
      'base': 'USD',
      'quotes': quotes.join(','),
    });
    final res = await http.get(uri).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    final data = jsonDecode(res.body);
    if (data is! List) throw Exception('Format tidak dikenal');

    final perUsd = <String, double>{'USD': 1};
    String? date;
    final now = DateTime.now();
    final rows = <Map<String, Object?>>[];
    for (final row in data) {
      if (row is! Map) continue;
      final quote = row['quote'];
      final rate = row['rate'];
      if (quote is! String || rate is! num) continue;
      perUsd[quote] = rate.toDouble();
      date ??= row['date'] as String?;
      rows.add({
        'quote': quote,
        'base': 'USD',
        'rate': rate.toDouble(),
        'rate_date': row['date'] as String?,
        'fetched_at': now.millisecondsSinceEpoch,
      });
    }
    if (rows.isEmpty) throw Exception('Data kosong');

    try {
      final db = await AppDatabase.instance.db;
      final batch = db.batch();
      for (final r in rows) {
        batch.insert('exchange_rates', r,
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    } catch (_) {
      // Gagal menyimpan cache tidak boleh menggagalkan tampilan kurs.
    }
    return RateTable(perUsd: perUsd, rateDate: date, fetchedAt: now);
  }

  Future<RateTable?> _readCache() async {
    try {
      final db = await AppDatabase.instance.db;
      final rows = await db.query('exchange_rates');
      if (rows.isEmpty) return null;
      final perUsd = <String, double>{'USD': 1};
      var latest = 0;
      String? date;
      for (final r in rows) {
        perUsd[r['quote'] as String] = (r['rate'] as num).toDouble();
        final at = r['fetched_at'] as int;
        if (at > latest) {
          latest = at;
          date = r['rate_date'] as String?;
        }
      }
      return RateTable(
        perUsd: perUsd,
        rateDate: date,
        fetchedAt: DateTime.fromMillisecondsSinceEpoch(latest),
      );
    } catch (_) {
      return null;
    }
  }
}

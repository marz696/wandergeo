import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';

import '../../../core/config/app_config.dart';
import '../../../core/database/app_database.dart';
import '../models/country.dart';
import 'country_seed.dart';

/// Sumber data negara + progres untuk Eksplorasi.
///
/// Alur: [loadLocal] (SQLite, cepat, bisa offline) lalu [refresh] (Supabase)
/// yang memperbarui SQLite. Bila SQLite kosong dan offline, dipakai
/// [CountrySeed] sebagai cadangan.
class CountryRepository {
  static const _columns =
      'code,name,capital,language,population,flag_url,latitude,longitude,'
      'region,timezone,currency_code,difficulty';

  /// Status awal bila belum ada baris progres: kesulitan 1 = terbuka.
  static CountryStatus _defaultStatus(Country c) =>
      c.difficulty == 1 ? CountryStatus.terbuka : CountryStatus.terkunci;

  static CountryStatus _parseStatus(Object? v) => switch (v) {
        'selesai' => CountryStatus.selesai,
        'terbuka' => CountryStatus.terbuka,
        _ => CountryStatus.terkunci,
      };

  static String _statusText(CountryStatus s) => switch (s) {
        CountryStatus.selesai => 'selesai',
        CountryStatus.terbuka => 'terbuka',
        CountryStatus.terkunci => 'terkunci',
      };

  List<Country> _merge(
    List<Country> countries,
    List<Map<String, Object?>> progress,
  ) {
    final byCode = {for (final p in progress) p['country_code'] as String: p};
    return [
      for (final c in countries)
        if (byCode[c.code] case final p?)
          c.copyWith(
            status: _parseStatus(p['status']),
            bestScore: (p['best_score'] as num?)?.toInt() ?? 0,
          )
        else
          c.copyWith(status: _defaultStatus(c)),
    ];
  }

  List<Country> _seed() => [
        for (final c in CountrySeed.all) c.copyWith(status: _defaultStatus(c)),
      ];

  /// Dari SQLite; cadangan seed bila kosong atau gagal dibaca.
  Future<List<Country>> loadLocal(String userId) async {
    try {
      final db = await AppDatabase.instance.db;
      final rows = await db.query('countries', orderBy: 'code');
      if (rows.isEmpty) return _seed();
      final progress = await db.query(
        'user_progress',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      return _merge([for (final r in rows) Country.fromRow(r)], progress);
    } catch (_) {
      return _seed();
    }
  }

  /// Dari Supabase lalu disimpan ke SQLite. Mengembalikan null bila gagal
  /// (offline, dll). [progress] = hasil `AuthRepository.fetchProgress()`;
  /// bila null, progres lokal yang sudah ada tetap dipakai.
  Future<List<Country>?> refresh({
    required String userId,
    List<Map<String, dynamic>>? progress,
  }) async {
    final countries = await _fetchCountries();
    if (countries == null || countries.isEmpty) return null;
    try {
      final db = await AppDatabase.instance.db;
      await db.transaction((txn) async {
        final batch = txn.batch();
        for (final c in countries) {
          batch.insert('countries', c.toRow(),
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
        if (progress != null) {
          batch.delete('user_progress',
              where: 'user_id = ?', whereArgs: [userId]);
          for (final p in progress) {
            batch.insert(
              'user_progress',
              {
                'user_id': userId,
                'country_code': p['country_code'],
                'status': p['status'],
                'best_score': p['best_score'] ?? 0,
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }
        await batch.commit(noResult: true);
      });
    } catch (_) {
      // Gagal menyimpan cache tidak boleh menggagalkan tampilan.
    }
    return loadLocal(userId);
  }

  Future<List<Country>?> _fetchCountries() async {
    if (!AppConfig.isConfigured || AppConfig.useMock) return null;
    try {
      final key = AppConfig.supabaseAnonKey;
      final res = await http.get(
        Uri.parse(
          '${AppConfig.supabaseUrl}/rest/v1/countries?select=$_columns&order=code',
        ),
        headers: {
          'apikey': key,
          if (key.startsWith('eyJ')) 'Authorization': 'Bearer $key',
        },
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body);
      if (data is! List) return null;
      return [
        for (final r in data)
          if (r is Map) Country.fromRow(Map<String, Object?>.from(r)),
      ];
    } catch (_) {
      return null;
    }
  }
}

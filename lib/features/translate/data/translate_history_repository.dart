import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';

class TranslateEntry {
  const TranslateEntry({
    required this.id,
    required this.sourceLabel,
    required this.original,
    required this.translated,
    required this.createdAt,
  });

  final int id;
  final String sourceLabel;
  final String original;
  final String translated;
  final DateTime createdAt;
}

/// Riwayat Terjemah Kamera di SQLite (lokal, per akun, maksimal 30 terakhir).
/// Tabelnya dibuat saat pertama dipakai, jadi `app_database.dart` tidak perlu diubah.
class TranslateHistoryRepository {
  static const _max = 30;

  Future<Database> _open() async {
    final db = await AppDatabase.instance.db;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS translate_history (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id      TEXT NOT NULL,
        source_label TEXT NOT NULL,
        original     TEXT NOT NULL,
        translated   TEXT NOT NULL,
        created_at   INTEGER NOT NULL
      )
    ''');
    return db;
  }

  Future<List<TranslateEntry>> list(String userId) async {
    try {
      final db = await _open();
      final rows = await db.query(
        'translate_history',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'id DESC',
        limit: _max,
      );
      return [
        for (final r in rows)
          TranslateEntry(
            id: r['id'] as int,
            sourceLabel: r['source_label'] as String,
            original: r['original'] as String,
            translated: r['translated'] as String,
            createdAt: DateTime.fromMillisecondsSinceEpoch(
              r['created_at'] as int,
            ),
          ),
      ];
    } catch (_) {
      return [];
    }
  }

  Future<void> add({
    required String userId,
    required String sourceLabel,
    required String original,
    required String translated,
  }) async {
    try {
      final db = await _open();
      await db.insert('translate_history', {
        'user_id': userId,
        'source_label': sourceLabel,
        'original': original,
        'translated': translated,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
      await db.rawDelete(
        'DELETE FROM translate_history WHERE user_id = ? AND id NOT IN '
        '(SELECT id FROM translate_history WHERE user_id = ? '
        'ORDER BY id DESC LIMIT $_max)',
        [userId, userId],
      );
    } catch (_) {
      // Gagal menyimpan riwayat tidak boleh menggagalkan terjemahan.
    }
  }

  Future<void> clear(String userId) async {
    try {
      final db = await _open();
      await db.delete(
        'translate_history',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
    } catch (_) {}
  }
}

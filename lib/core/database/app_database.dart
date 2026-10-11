import 'package:sqflite/sqflite.dart';

/// Database lokal (SQLite). Saat ini menyimpan cache kurs; tabel lain
/// (negara, misi, progres, stempel paspor) menyusul dengan menaikkan `version`.
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get db async => _db ??= await _open();

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    return openDatabase(
      '$dir/wandergeo.db',
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE exchange_rates (
            quote      TEXT PRIMARY KEY,
            base       TEXT NOT NULL,
            rate       REAL NOT NULL,
            rate_date  TEXT,
            fetched_at INTEGER NOT NULL
          )
        ''');
      },
    );
  }
}

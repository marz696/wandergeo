import 'package:sqflite/sqflite.dart';

/// Database lokal (SQLite): cache kurs, negara, dan progres pengguna.
/// Tabel baru (misi, stempel paspor) ditambahkan dengan menaikkan `version`
/// dan menulis langkahnya di `onUpgrade`.
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get db async => _db ??= await _open();

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    return openDatabase(
      '$dir/wandergeo.db',
      version: 2,
      onCreate: (db, version) async {
        await _createRates(db);
        await _createCountries(db);
        await _createProgress(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createCountries(db);
          await _createProgress(db);
        }
      },
    );
  }

  Future<void> _createRates(Database db) => db.execute('''
    CREATE TABLE exchange_rates (
      quote      TEXT PRIMARY KEY,
      base       TEXT NOT NULL,
      rate       REAL NOT NULL,
      rate_date  TEXT,
      fetched_at INTEGER NOT NULL
    )
  ''');

  /// Salinan tabel `countries` di Supabase (nama kolom sama).
  Future<void> _createCountries(Database db) => db.execute('''
    CREATE TABLE countries (
      code          TEXT PRIMARY KEY,
      name          TEXT NOT NULL,
      capital       TEXT NOT NULL,
      language      TEXT,
      population    INTEGER,
      flag_url      TEXT,
      latitude      REAL NOT NULL,
      longitude     REAL NOT NULL,
      region        TEXT NOT NULL,
      timezone      TEXT NOT NULL,
      currency_code TEXT NOT NULL,
      difficulty    INTEGER NOT NULL DEFAULT 1
    )
  ''');

  /// Salinan progres per pengguna (satu perangkat bisa dipakai beberapa akun).
  Future<void> _createProgress(Database db) => db.execute('''
    CREATE TABLE user_progress (
      user_id      TEXT NOT NULL,
      country_code TEXT NOT NULL,
      status       TEXT NOT NULL,
      best_score   INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (user_id, country_code)
    )
  ''');
}

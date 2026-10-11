/// Konfigurasi aplikasi.
///
/// Mode mock = true  -> login berjalan tanpa backend (untuk demo UI).
/// Mode mock = false -> memakai Supabase Edge Function `login`.
///
/// Jalankan dengan kunci Supabase tanpa menyimpannya di kode:
///   flutter run --dart-define=SUPABASE_URL=https://xxx.supabase.co \
///               --dart-define=SUPABASE_ANON_KEY=xxxxx
class AppConfig {
  AppConfig._();

  static const bool useMock = true;

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');
}

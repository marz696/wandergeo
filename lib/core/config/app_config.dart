/// Konfigurasi aplikasi.
///
/// Tanpa kunci Supabase -> mode mock (login simulasi, untuk demo UI).
/// Dengan kunci -> memakai Edge Function `auth` di Supabase.
///
/// Salin dart_defines.example.json menjadi dart_defines.json, isi nilainya, lalu:
///   flutter run --dart-define-from-file=dart_defines.json
class AppConfig {
  AppConfig._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  static const bool useMock = supabaseUrl == '' || supabaseAnonKey == '';
}

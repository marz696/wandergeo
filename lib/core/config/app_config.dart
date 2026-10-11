/// Konfigurasi aplikasi.
///
/// Login selalu memakai Edge Function `auth` di Supabase, jadi hanya akun
/// yang ada di tabel `users` yang bisa masuk. Cukup `flutter run` biasa.
///
/// Mode mock (login simulasi yang menerima password apa pun) HANYA menyala
/// bila diminta eksplisit, mis. untuk demo UI tanpa internet:
///   flutter run --dart-define=USE_MOCK=true
class AppConfig {
  AppConfig._();

  // Nilai bawaan = project Supabase WanderGeo, jadi `flutter run` biasa sudah
  // terhubung. Kunci "publishable" memang dirancang untuk dipasang di aplikasi
  // (akses data tetap dijaga RLS dan Edge Function). JANGAN PERNAH menaruh
  // service_role key di sini. Bisa ditimpa lewat --dart-define-from-file.
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://udsfmshektndrepbhthn.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_moAAVGPh3cBCD5LQBGimgA_qWtxATP5',
  );

  static const bool useMock = bool.fromEnvironment('USE_MOCK');

  static const bool isConfigured =
      supabaseUrl != '' && supabaseAnonKey != '';
}
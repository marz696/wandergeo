# WanderGeo - Splash & Login (Flutter)

Alur: native splash (OS) -> `SplashPage` (globe + pesawat mengorbit) -> `LoginPage` -> `SuccessOverlay` -> halaman Eksplorasi (placeholder).

## Menjalankan
1. Buat project: `flutter create wandergeo`, lalu salin `lib/`, `assets/`, `tool/`, dan `pubspec.yaml` dari zip ini ke dalamnya (timpa). Hapus `test/widget_test.dart` bawaan.
2. `flutter pub get`
3. Atur nama dan izin platform: `dart run tool/setup_platform.dart`
   (nama aplikasi "WanderGeo", izin INTERNET + biometrik, FlutterFragmentActivity, NSFaceIDUsageDescription)
4. Ikon aplikasi (logo W): `dart run flutter_launcher_icons`
5. Splash bawaan OS (latar `#F4F8FA`, menyatu dengan splash Flutter): `dart run flutter_native_splash:create`
6. `flutter run` (default memakai mode mock: password minimal 6 karakter)

Jika ikon atau nama lama masih muncul di simulator: hapus aplikasinya dari simulator, lalu `flutter clean && flutter run`.

## Mode Supabase
Ubah `AppConfig.useMock` menjadi `false`, lalu jalankan:
`flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`
Butuh Edge Function `login` yang mengembalikan `{ "token": "..." }`.

## Logo
`lib/core/widgets/wandergeo_logo.dart` berisi `WanderGeoLogo` (bisa `animate: true`) dan `WanderGeoWordmark`,
masing-masing punya varian `.onDark`. Belum dipakai di halaman login (mockup tidak menampilkannya di sana).

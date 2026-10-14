# WanderGeo - Splash, Login, Eksplorasi (Flutter)

Alur: native splash (OS) -> `SplashPage` -> `LoginPage` -> `SuccessOverlay` -> `MainShell`
(bottom navigation pill 5 tab: Eksplorasi, Paspor Digital, Profil, Kesan & Saran, Logout).
Hanya tab Eksplorasi yang sudah jadi; tab lain masih halaman sementara (`TabPlaceholderPage`).

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

## Login (Supabase)
Login dan daftar memakai Edge Function `auth` (`supabase/functions/auth/index.ts`): password di-hash bcrypt,
sesi berupa token acak yang di server hanya disimpan sebagai hash SHA-256. Langkah menyiapkannya ada di
`supabase/PETUNJUK_SUPABASE.md`. Tanpa kunci Supabase, aplikasi berjalan dalam mode mock (login simulasi).
Jalankan dengan kunci: salin `dart_defines.example.json` menjadi `dart_defines.json`, isi, lalu
`flutter run --dart-define-from-file=dart_defines.json`. Tambahkan `dart_defines.json` ke `.gitignore`.

## Misi
`features/mission/`: tiap negara punya 3 misi. Trivia (20 soal, 15 detik/soal) dan Kuliner & Budaya (4 kartu flip) WAJIB;
Mini Game "Tangkap Koin" (accelerometer) opsional. Negara selesai bila trivia dan budaya lulus; saat itu 2 negara terkunci
terdekat dibuka. Penilaian dilakukan di server (Edge Function `auth`: `country_missions`, `mission_content`, `submit_mission`).
Jalankan `supabase/migrations/002_misi.sql` (240 soal, 48 kartu) dan deploy ulang fungsi `auth`.

## Alat Perjalanan
`features/tools/`: konversi mata uang (12 mata uang, kurs Frankfurter v2 lewat `core/services/currency_service.dart`,
disimpan di SQLite `core/database/app_database.dart` agar jalan offline) dan konversi waktu WIB/WITA/WIT/London
(London otomatis BST/GMT, tanpa API). Konversi antar mata uang dihitung silang lewat USD.

## Eksplorasi
`lib/features/explore/`: peta penuh layar (`flutter_map` + tile OpenStreetMap, tanpa API key/billing),
header (judul, Alat Perjalanan, Tanya Pemandu, koin), pencarian, filter status, urut, pengalih ASEAN/UK,
pin negara (selesai/terbuka/terkunci), carousel negara, dan panel detail.
- LBS: `core/services/location_service.dart` (geolocator, cadangan Jakarta) + haversine di `core/utils/geo_utils.dart`.
- Sensor 1: `core/services/compass_service.dart` (flutter_compass). Di emulator tanpa sensor, jarum diam.
- API: Wikipedia REST (ringkasan + foto, `wikipedia_service.dart`) dan Open-Meteo (cuaca, `weather_service.dart`). Keduanya gratis tanpa key.
- Rekomendasi AI (non-LLM): `features/explore/logic/recommender.dart`.
- Data awal: `features/explore/data/country_seed.dart` (12 negara, status contoh). Ganti dengan SQLite + Supabase nanti.
- Tombol Alat Perjalanan membuka `features/tools/alat_perjalanan_page.dart`. Tanya Pemandu dan Mulai Misi masih snackbar "segera hadir".
- Atribusi "© OpenStreetMap contributors" wajib tetap tampil; tile publik OSM hanya untuk pemakaian ringan.

Setelah menimpa file, jalankan lagi `flutter pub get` dan `dart run tool/setup_platform.dart` (izin lokasi + internet); database SQLite dibuat otomatis saat pertama dipakai.

# WanderGeo: Passport to the World

Aplikasi mobile geografi bergamifikasi untuk menjelajahi **negara negara ASEAN dan Inggris Raya (UK)**.
Pengguna menjelajah peta, menyelesaikan misi di tiap negara, mengumpulkan **stempel paspor digital**
(disimpan sebagai rantai blok sederhana), bertanya kepada **Pemandu AI**, dan menerjemahkan tulisan asing lewat kamera.

> Projek akhir mata kuliah **Pemrograman Aplikasi Mobile** · Flutter (Dart) · Supabase

---

## Daftar Isi

1. [Fitur](#fitur)
2. [Tangkapan Layar](#tangkapan-layar)
3. [Teknologi](#teknologi)
4. [Arsitektur](#arsitektur)
5. [Struktur Folder](#struktur-folder)
6. [Menjalankan Aplikasi](#menjalankan-aplikasi)
7. [Menyiapkan Supabase](#menyiapkan-supabase)
8. [Backend (Supabase Edge Function)](#backend-supabase-edge-function)
9. [Database](#database)
10. [API Eksternal](#api-eksternal)
11. [Alur Aplikasi](#alur-aplikasi)
12. [Pemetaan Kriteria Tugas](#pemetaan-kriteria-tugas)
13. [Catatan Keamanan](#catatan-keamanan)
14. [Pemecahan Masalah](#pemecahan-masalah)
15. [Keterbatasan](#keterbatasan)

---

## Fitur

| Area | Penjelasan |
|---|---|
| **Autentikasi** | Daftar dan masuk lewat Edge Function tanpa Firebase. Password disimpan sebagai hash bcrypt di server. Sesi berupa token acak yang hanya disimpan server sebagai hash SHA 256, dan di perangkat disimpan di Secure Storage (Keychain atau Keystore) bila "Ingat saya" aktif. Akun dikunci 15 menit setelah 5 kali gagal login. |
| **Login biometrik** | Sidik jari atau wajah (`local_auth`) membuka kembali sesi yang tersimpan. |
| **Lupa password** | Kode verifikasi 6 digit dikirim ke email lewat Brevo. Kode berlaku 15 menit, dibatasi 5 percobaan, dan jeda minta ulang 60 detik. Setelah berhasil, semua sesi lama dicabut. |
| **Eksplorasi** | Peta layar penuh (OpenStreetMap), pin negara berstatus *terkunci*, *terbuka*, atau *selesai*, carousel negara, dan panel detail berisi ringkasan Wikipedia, foto, cuaca ibu kota, dan jarak. |
| **Pencarian dan pemilihan** | Pencarian nama, ibu kota, atau kode negara, filter status, urutan (jarak, nama, kesulitan), dan pengalih ASEAN atau UK. |
| **LBS** | Lokasi pengguna (`geolocator`), jarak haversine ke tiap negara, tombol "ke lokasiku", dan garis rute putus putus ke negara terpilih. Lokasi cadangan: Jakarta. |
| **Sensor** | Magnetometer untuk kompas peta dan accelerometer untuk kontrol mini game. |
| **Misi** | Tiga misi per negara: **Trivia** (15 detik per soal), **Kuliner dan Budaya** (kartu), dan **Mini game Tangkap Koin** (opsional). Penilaian dilakukan di server. |
| **Mini game** | *Tangkap Koin*: miringkan HP untuk menggerakkan keranjang, 20 detik, target 100 poin. |
| **Koin, Visa Cepat, dan petunjuk** | Koin didapat dari misi yang pertama kali lulus. Negara terkunci dapat dibuka dengan Visa Cepat (50 koin dikali tingkat kesulitan), dan petunjuk soal trivia seharga 3 koin. Pemotongan koin dikerjakan atomik di fungsi database. |
| **Pemandu AI (LLM)** | Tanya jawab dan soal latihan dengan Gemini lewat server, dengan kuota harian (bawaan 10 pertanyaan) dan riwayat percakapan yang tersimpan di SQLite. |
| **Terjemah Kamera (AI di perangkat)** | Foto papan atau menu dibaca dengan ML Kit Text Recognition lalu diterjemahkan ke bahasa Indonesia dengan ML Kit On Device Translation. Bahasa sumber: Inggris, Melayu, Vietnam, dan Filipino. Riwayat 30 terakhir disimpan di SQLite. |
| **Rekomendasi negara** | Negara berikutnya dipilih dengan aturan: tingkat kesulitan sebagai faktor utama, jarak sebagai penentu bila kesulitan sama (`recommender.dart`). |
| **Paspor digital (blockchain)** | Tiap stempel adalah satu blok (`previous_hash`, `hash`, `nonce`, proof of work berawalan `00`). Server memverifikasi seluruh rantai, dan tabelnya dikunci agar hanya bisa ditambah. |
| **Alat Perjalanan** | Konversi 12 mata uang (kurs disimpan untuk dipakai offline) dan konversi waktu **WIB, WITA, WIT, London** (otomatis GMT dan BST). |
| **Profil** | Foto profil (kamera atau galeri) yang diunggah ke Supabase Storage, ubah nama tampilan, serta statistik progres dan koin. |
| **Kesan dan Saran** | Kesan dan saran untuk mata kuliah Pemrograman Aplikasi Mobile: kirim dengan penilaian wajah dan chip, lihat semua kesan, dan hapus kiriman sendiri. |
| **Notifikasi** | Notifikasi lokal: pengingat harian (7 hari ke depan, isi mengikuti progres) dan kabar pencapaian saat negara selesai. |
| **Data lokal dan online** | SQLite untuk cache negara, progres, kurs, riwayat chat, dan riwayat terjemah. Supabase (PostgreSQL) sebagai sumber data online. |

---

## Tangkapan Layar

Folder `docs/screenshots/` belum ada di repositori. Buat folder tersebut, isi dengan gambar, dan sesuaikan nama berkas berikut.

| Splash | Login | Eksplorasi | Detail Negara |
|:--:|:--:|:--:|:--:|
| ![Splash](docs/screenshots/01-splash.png) | ![Login](docs/screenshots/02-login.png) | ![Eksplorasi](docs/screenshots/03-eksplorasi.png) | ![Detail](docs/screenshots/04-detail-negara.png) |

| Misi | Trivia | Mini Game | Pemandu AI |
|:--:|:--:|:--:|:--:|
| ![Misi](docs/screenshots/05-misi.png) | ![Trivia](docs/screenshots/06-trivia.png) | ![Mini game](docs/screenshots/07-minigame.png) | ![Pemandu](docs/screenshots/08-pemandu.png) |

| Paspor | Alat Perjalanan | Profil | Kesan dan Saran |
|:--:|:--:|:--:|:--:|
| ![Paspor](docs/screenshots/09-paspor.png) | ![Alat](docs/screenshots/10-alat-perjalanan.png) | ![Profil](docs/screenshots/11-profil.png) | ![Kesan](docs/screenshots/12-kesan-saran.png) |

| Lupa Password | Terjemah Kamera |
|:--:|:--:|
| ![Lupa password](docs/screenshots/13-lupa-password.png) | ![Terjemah Kamera](docs/screenshots/14-terjemah-kamera.png) |

---

## Teknologi

| Kebutuhan | Paket atau layanan |
|---|---|
| Framework | Flutter, Dart SDK `>=3.3.0 <4.0.0` |
| State management | `provider` |
| Backend | Supabase (Edge Function `auth`, PostgreSQL, Storage) lewat `supabase_flutter` dan `http` |
| Penyimpanan aman | `flutter_secure_storage` |
| Biometrik | `local_auth` |
| Database lokal | `sqflite`, `shared_preferences`, `path_provider` |
| Peta dan LBS | `flutter_map`, `latlong2`, `geolocator` |
| Sensor | `flutter_compass` (magnetometer), `sensors_plus` (accelerometer) |
| AI di perangkat | `google_mlkit_text_recognition`, `google_mlkit_translation` |
| Notifikasi | `flutter_local_notifications`, `timezone` |
| Media | `image_picker` |
| UI | `google_fonts` (Sora untuk judul, DM Sans untuk isi) |
| Layanan server | Gemini API (pemandu AI), Brevo API (email kode reset) |
| Tooling | `flutter_native_splash`, `flutter_launcher_icons`, `flutter_lints` |

---

## Arsitektur

```
┌──────────────────────────── Aplikasi Flutter ────────────────────────────┐
│  Halaman (features/*)  ──►  Repository  ──►  Service / Database lokal    │
│   login, explore,            AuthRepository     LocationService (GPS)     │
│   mission, guide,            CountryRepository  CompassService            │
│   passport, tools,           MissionRepository  CurrencyService           │
│   translate, profile,        GuideRepository    NotificationService       │
│   feedback                   PassportRepository OcrService, Translate     │
│                              SecureStorage, SQLite    (ML Kit)            │
└───────────────┬───────────────────────────────┬───────────────────────────┘
                │ HTTPS POST                    │ HTTPS GET (tanpa key)
                ▼                               ▼
   Supabase Edge Function `auth`        Wikipedia, Open Meteo, Frankfurter
   (login, misi, paspor, dan lain lain) OpenStreetMap (tile peta)
        │          │          │
        ▼          ▼          ▼
   PostgreSQL   Storage    Gemini API dan Brevo API
                (avatars)  (kunci hanya di server)
```

Aturan utama: **halaman tidak memanggil server langsung**, semua akses data lewat repository.
Penilaian misi, pembelian koin, verifikasi blockchain, pemanggilan Gemini, dan pengiriman email
(beserta kunci APInya) hanya ada di server. Terjemah Kamera berjalan sepenuhnya di perangkat.

---

## Struktur Folder

```
lib/
├── main.dart, app.dart, routes.dart
├── core/
│   ├── config/        app_config.dart            # URL dan kunci Supabase, mode mock
│   ├── data/          currencies.dart, coin_prices.dart
│   ├── database/      app_database.dart          # SQLite (versi 3)
│   ├── services/      location, compass, currency, weather, wikipedia,
│   │                  biometric, secure_storage, profile (foto),
│   │                  ocr_service, translate_service
│   ├── theme/         app_colors.dart, app_theme.dart
│   ├── utils/         geo_utils, format_utils, paint_utils
│   └── widgets/       tombol, text field, logo
└── features/
    ├── splash/        splash_page, globe_painter
    ├── auth/          login, register, lupa dan reset password,
    │                  auth_repository, login_controller
    ├── shell/         main_shell, floating_nav_bar
    ├── explore/       peta, pencarian, filter, rekomendasi, panel detail, visa
    ├── mission/       hub, trivia, kuliner dan budaya, mini game, hasil
    ├── guide/         Tanya Pemandu (LLM)
    ├── passport/      paspor digital (blockchain) dan widgets/
    ├── tools/         Alat Perjalanan: kurs dan jam dunia
    ├── translate/     Terjemah Kamera (ML Kit) dan riwayat
    ├── profile/       profil dan foto
    ├── feedback/      kesan dan saran
    └── notifications/ pengingat harian dan notifikasi pencapaian

supabase/
├── geoquest_schema_v2.sql        # skema dasar
├── migrations/                   # 001 sampai 009, dijalankan berurutan
├── functions/auth/index.ts       # Edge Function tunggal
└── PETUNJUK_SUPABASE.md          # langkah menyiapkan Supabase

tool/setup_platform.dart          # pengaturan izin dan nama aplikasi
dart_defines.json                 # SUPABASE_URL dan SUPABASE_ANON_KEY
```

---

## Menjalankan Aplikasi

### Prasyarat

- Flutter SDK dengan Dart `>=3.3.0`
- Android Studio atau Xcode (untuk emulator atau perangkat nyata)
- Koneksi internet (kecuali mode mock)
- Untuk uji sensor dan biometrik: **perangkat nyata**, karena emulator tidak memiliki magnetometer dan biometrik sungguhan
- Untuk iOS: target minimum **iOS 15.5** (syarat ML Kit). Naikkan `IPHONEOS_DEPLOYMENT_TARGET` di Xcode, dan jika ada `ios/Podfile` pastikan barisnya `platform :ios, '15.5'`

### Langkah

```bash
git clone https://github.com/marz696/wandergeo.git
cd wandergeo

flutter pub get

# jika nama aplikasi dan izin platform belum terpasang
# (izin: internet, biometrik, lokasi, nama "WanderGeo", FlutterFragmentActivity)
dart run tool/setup_platform.dart

# ikon aplikasi dan splash bawaan OS
dart run flutter_launcher_icons
dart run flutter_native_splash:create

flutter run
```

Jika ikon atau nama lama masih muncul di emulator, hapus aplikasinya lalu jalankan `flutter clean && flutter run`.

### Konfigurasi Supabase

Nilai bawaan di `lib/core/config/app_config.dart` menunjuk ke proyek Supabase WanderGeo.
Untuk memakai proyek sendiri, isi `dart_defines.json`:

```json
{
  "SUPABASE_URL": "https://<project-ref>.supabase.co",
  "SUPABASE_ANON_KEY": "<publishable-key>"
}
```

lalu jalankan:

```bash
flutter run --dart-define-from-file=dart_defines.json
```

Nilai juga dapat diberikan satu per satu dengan `--dart-define=SUPABASE_URL=...` dan `--dart-define=SUPABASE_ANON_KEY=...`.

### Mode mock (demo tampilan tanpa internet)

```bash
flutter run --dart-define=USE_MOCK=true
```

Mode ini mensimulasikan login (password minimal 6 karakter) dan hanya membuka tampilan.
Misi, paspor, Pemandu AI, lupa password, serta kesan dan saran **membutuhkan server**, sehingga tidak berfungsi di mode mock.

---

## Menyiapkan Supabase

Langkah lengkap ada di `supabase/PETUNJUK_SUPABASE.md`. Ringkasnya:

1. Buat proyek di supabase.com.
2. Di **SQL Editor**, jalankan `supabase/geoquest_schema_v2.sql`, lalu `supabase/migrations/001` sampai `009` secara berurutan.
3. Data awal sudah termuat di skrip SQL: negara pada `geoquest_schema_v2.sql`, serta misi, soal trivia, dan kartu budaya pada `002_misi.sql`. Tabel konten tidak perlu diisi manual.
4. Di **Edge Functions**, deploy fungsi `auth` dari `supabase/functions/auth/index.ts` dengan **Verify JWT dimatikan** (endpoint ini publik dan identitas diperiksa di dalam fungsi). Dengan CLI: `supabase functions deploy auth --no-verify-jwt`.
5. Di **Edge Functions > Secrets**, isi variabel berikut.

| Secret | Fungsi |
|---|---|
| `GEMINI_API_KEY` | Wajib untuk Pemandu AI |
| `BREVO_API_KEY` | Wajib untuk email kode reset password |
| `MAIL_FROM_EMAIL` | Wajib, alamat pengirim yang sudah diverifikasi di Brevo |
| `MAIL_FROM_NAME` | Opsional, nama pengirim (bawaan WanderGeo) |
| `RESET_PEPPER` | Opsional, rahasia tambahan untuk hash kode reset |
| `GEMINI_MODEL` | Opsional, daftar model dipisah koma yang dicoba berurutan |
| `GEMINI_TIMEOUT_MS` | Opsional, batas tunggu per model (bawaan 20000) |
| `GUIDE_DAILY_LIMIT` | Opsional, kuota pertanyaan pemandu per hari (bawaan 10) |

`SUPABASE_URL` dan `SUPABASE_SERVICE_ROLE_KEY` disediakan otomatis oleh Supabase untuk Edge Function.

---

## Backend (Supabase Edge Function)

Seluruh aksi aplikasi memakai satu endpoint:

```
POST {SUPABASE_URL}/functions/v1/auth
Body: { "action": "<nama>", "token": "<token sesi>", ... }
```

| Action | Fungsi |
|---|---|
| `register`, `login`, `me`, `logout` | Pendaftaran, masuk, validasi sesi, dan akhiri sesi |
| `forgot_request`, `forgot_reset` | Minta kode reset lewat email, lalu ganti password dengan kode |
| `profile`, `update_profile`, `progress` | Data akun dan statistik, ubah nama, progres per negara |
| `upload_avatar`, `remove_avatar` | Unggah dan hapus foto profil di Storage |
| `country_missions`, `mission_content`, `submit_mission` | Daftar misi, soal atau kartu, kirim jawaban (dinilai server) |
| `buy_visa`, `trivia_hint` | Beli Visa Cepat dan petunjuk soal dengan koin |
| `passport` | Rantai blok paspor beserta hasil verifikasi |
| `guide_quota`, `guide_chat`, `guide_quiz` | Kuota harian, chat LLM, soal latihan |
| `feedback_list`, `feedback_all`, `feedback_save`, `feedback_delete` | Kesan dan saran |

Daftar negara dibaca langsung dari REST: `GET /rest/v1/countries`.

---

## Database

### Online (Supabase PostgreSQL)

Tiga belas tabel: `users`, `sessions`, `password_resets`, `guide_usage`, `feedbacks`, `countries`, `missions`,
`quiz_questions`, `culture_cards`, `user_missions`, `user_progress`, `trivia_hints`, dan `passport_stamps`.
Tabel yang berisi data pengguna diaktifkan Row Level Security tanpa kebijakan, sehingga hanya Edge Function
(service role) yang dapat membacanya. Hanya `countries` yang dibaca langsung oleh aplikasi.

### Lokal (SQLite)

Berkas `wandergeo.db`, versi skema **3** (`lib/core/database/app_database.dart`).

| Tabel | Kegunaan |
|---|---|
| `exchange_rates` | Cache kurs terhadap USD (dianggap segar 6 jam) |
| `countries` | Salinan tabel `countries` Supabase untuk mode offline |
| `user_progress` | Status dan skor terbaik per pengguna per negara |
| `chat_messages` | Riwayat percakapan Pemandu per akun dan per negara |
| `translate_history` | Riwayat Terjemah Kamera per akun (dibuat otomatis saat pertama dipakai) |

Pola pemuatan data: **SQLite dulu (cepat dan bisa offline), lalu sinkron dari Supabase**.
Bila SQLite kosong dan tidak ada internet, dipakai data awal `country_seed.dart`.

---

## API Eksternal

| Layanan | Dipakai untuk | Catatan |
|---|---|---|
| OpenStreetMap tile | Peta | Atribusi "© OpenStreetMap contributors" wajib tampil. Tile publik hanya untuk pemakaian ringan |
| Wikipedia REST (bahasa Indonesia) | Ringkasan dan foto negara | Wajib mengirim `User-Agent` |
| Open Meteo | Cuaca ibu kota | Gratis, tanpa key, non komersial. Disimpan sementara 15 menit |
| Frankfurter v2 | Kurs mata uang | Gratis, tanpa key. Disimpan di SQLite selama 6 jam |
| Gemini (lewat server) | Pemandu AI | API key hanya di server |
| Brevo (lewat server) | Email kode reset password | API key hanya di server |
| ML Kit (di perangkat) | Terjemah Kamera | Model bahasa diunduh sekali, setelah itu dapat dipakai tanpa internet |

---

## Alur Aplikasi

```
Splash OS ─► SplashPage ─► LoginPage ─► (animasi sukses) ─► MainShell
                              │  ▲  │
              biometrik ──────┘  │  └── Lupa password ─► Reset password
                                 └───── RegisterPage

MainShell (bottom navigation, 5 tab):
  Eksplorasi │ Paspor Digital │ Profil │ Kesan dan Saran │ Logout (dialog)

Eksplorasi ─► Detail negara ─► Misi (Trivia, Kuliner dan Budaya, Mini game)
          │                └─► Buka Visa (negara terkunci)
          ├─► Tanya Pemandu (LLM)
          └─► Alat Perjalanan ─► Kurs, Jam dunia, Terjemah Kamera

Profil ─► Pengaturan notifikasi
```

Negara dengan tingkat kesulitan 1 terbuka sejak awal. Menyelesaikan dua misi wajib
(Trivia, Kuliner dan Budaya) menyelesaikan negara, menambah blok ke paspor, dan membuka dua negara lain.
Logout bersifat khusus: bila "Ingat saya" aktif, token tetap tersimpan agar bisa masuk lagi dengan biometrik,
dan bila tidak aktif, token dihapus dari perangkat dan dicabut di server.

---

## Pemetaan Kriteria Tugas

| Kriteria | Implementasi |
|---|---|
| Konsep projek akhir | WanderGeo, geografi ASEAN dan UK bergamifikasi |
| Login terenkripsi dan session (tanpa Firebase) | Edge Function `auth`, hash bcrypt dan token sesi berhash di server, token di `flutter_secure_storage` |
| Login biometrik | `local_auth` (`BiometricService`, `LoginController`) |
| Database lokal dan online | SQLite (`sqflite`) dan Supabase PostgreSQL |
| Web service atau API dan LBS | Edge Function, REST, Wikipedia, Open Meteo, Frankfurter, `geolocator` dan haversine |
| Bottom navigation: profil (gambar), kesan dan saran PAM, logout | `MainShell` dan `FloatingNavBar` |
| Konversi mata uang (minimal 3) dan waktu (WIB, WIT, WITA, London) | `CurrencyCard` (12 mata uang), `WorldTimeCard` |
| Minimal 2 sensor | Magnetometer (kompas) dan accelerometer (mini game) |
| AI dan LLM | Gemini (Tanya Pemandu), ML Kit (Terjemah Kamera), dan rekomendasi berbasis aturan (`recommender.dart`) |
| Mini game | Tangkap Koin |
| Pencarian dan pemilihan | Pencarian, filter, urutan, dan pengalih wilayah di Eksplorasi |
| Notifikasi mobile | `flutter_local_notifications` (pengingat harian dan pencapaian) |
| Blockchain sederhana | Paspor berupa rantai blok SHA 256 dengan proof of work |

---

## Catatan Keamanan

- Kunci `sb_publishable_...` atau anon di aplikasi memang dirancang untuk publik. Akses data dijaga RLS dan Edge Function.
  **Jangan pernah** menaruh `service_role` key, API key Gemini, atau API key Brevo di aplikasi.
- Password tidak disimpan di perangkat. Yang tersimpan di Secure Storage hanya token sesi dan data akun ringkas, itu pun hanya bila "Ingat saya" aktif.
- Di server, password disimpan sebagai hash bcrypt dan token sesi hanya sebagai hash SHA 256.
- Waktu respons untuk username yang tidak dikenal disamakan dengan password salah, dan jawaban lupa password sama baik akun ada maupun tidak.
- Penilaian misi, pembelian koin, dan verifikasi rantai dilakukan di server sehingga tidak bisa dipalsukan dari aplikasi.
- Brevo punya fitur pembatasan alamat IP. Bila aktif, permintaan dari Edge Function ditolak karena alamat IP Edge Function tidak tetap.

---

## Pemecahan Masalah

| Gejala | Penyebab atau solusi |
|---|---|
| Notifikasi tidak pernah muncul | Pastikan drawable `ic_stat_wandergeo` ada di `android/app/src/main/res/`, izin notifikasi diberikan (Android 13 ke atas), dan uji lewat *Pengaturan Notifikasi, Kirim notifikasi uji*. |
| Biometrik "tidak ada sesi" | Login dulu dengan password dan **Ingat saya** aktif. Biometrik hanya membuka sesi yang tersimpan. |
| Kompas diam | Emulator tidak punya magnetometer. Uji di HP asli. |
| Keranjang mini game bergerak terbalik | Ubah `_tiltSign` (dari 1 menjadi minus 1, atau sebaliknya) di `minigame_page.dart`. |
| "Tidak dapat terhubung ke server" | Periksa internet serta nilai `SUPABASE_URL` dan `SUPABASE_ANON_KEY`. |
| Kurs belum tersedia | Sambungkan internet sekali agar kurs terunduh dan tersimpan di SQLite. |
| Email kode reset tidak masuk | Periksa folder spam, lalu buka *Edge Functions, auth, Logs* di Supabase. Galat `401` dari Brevo biasanya berarti pembatasan IP aktif, matikan di menu Security Brevo. Pastikan juga `BREVO_API_KEY` dan `MAIL_FROM_EMAIL` terisi dan pengirim sudah diverifikasi. |
| Terjemah Kamera gagal di pemakaian pertama | Model bahasa perlu diunduh sekali, jadi sambungkan internet. Fitur ini tidak tersedia di Flutter Web. |
| Build iOS gagal karena ML Kit | Naikkan target iOS ke 15.5. Jika memakai simulator, uji di perangkat asli. |
| Pemandu AI menjawab "tidak tersedia" | Periksa `GEMINI_API_KEY` dan nama model pada `GEMINI_MODEL`, lalu lihat Logs fungsi `auth`. |

---

## Keterbatasan

- Fitur yang bergantung pada server (misi, paspor, Pemandu AI, lupa password, kesan dan saran) tidak bekerja offline.
- Kuota Pemandu AI dibatasi per hari per pengguna.
- Pembaca teks Terjemah Kamera hanya mengenali aksara Latin, sehingga papan beraksara Thai, Khmer, Lao, dan Myanmar belum terbaca.
- Paspor digital berupa rantai hash di satu server. Perubahan dapat dideteksi, tetapi tidak ada jaringan peserta yang menyepakati isi rantai.
- Rekomendasi negara berbasis aturan sederhana dan tidak belajar dari data.
- Tile OpenStreetMap publik tidak untuk lalu lintas tinggi.
- Notifikasi bersifat lokal dan dijadwalkan tidak eksak (dapat tertunda beberapa menit).

---

## Pembuat

**Damar Nugroho** (124240073)
**Azhicry Vernando Etsria Putra** (124240069)

# WanderGeo — Passport to the World

Aplikasi mobile geografi bergamifikasi untuk menjelajahi **negara-negara ASEAN dan Inggris Raya (UK)**.
Pengguna menjelajah peta, menyelesaikan misi di tiap negara, mengumpulkan **stempel paspor digital**
(disimpan sebagai rantai blockchain sederhana), dan bertanya kepada **Pemandu AI**.

> Tugas Akhir mata kuliah **Pemrograman Aplikasi Mobile** · Flutter (Dart) · Supabase

---

## Daftar Isi

1. [Fitur](#fitur)
2. [Tangkapan Layar](#tangkapan-layar)
3. [Teknologi](#teknologi)
4. [Arsitektur](#arsitektur)
5. [Struktur Folder](#struktur-folder)
6. [Menjalankan Aplikasi](#menjalankan-aplikasi)
7. [Backend (Supabase Edge Function)](#backend-supabase-edge-function)
8. [Database Lokal (SQLite)](#database-lokal-sqlite)
9. [API Eksternal](#api-eksternal)
10. [Alur Aplikasi](#alur-aplikasi)
11. [Pemetaan Kriteria Tugas](#pemetaan-kriteria-tugas)
12. [Catatan Keamanan](#catatan-keamanan)
13. [Pemecahan Masalah](#pemecahan-masalah)
14. [Keterbatasan](#keterbatasan)

---

## Fitur

| Area | Penjelasan |
|---|---|
| **Autentikasi** | Daftar dan masuk lewat Edge Function (tanpa Firebase). Password diverifikasi dengan hash di server; sesi berupa token yang disimpan di Secure Storage (Keychain/Keystore) bila "Ingat saya" aktif. |
| **Login biometrik** | Sidik jari / wajah (`local_auth`) membuka kembali sesi tersimpan. |
| **Eksplorasi** | Peta layar penuh (OpenStreetMap), pin negara berstatus *terkunci / terbuka / selesai*, carousel negara, panel detail (ringkasan Wikipedia, foto, cuaca ibukota). |
| **Pencarian dan pemilihan** | Pencarian nama/ibukota/kode, filter status, urut (jarak, nama, kesulitan), pengalih ASEAN/UK. |
| **LBS** | Lokasi pengguna (`geolocator`), jarak haversine ke tiap negara, tombol "ke lokasiku", garis rute ke negara terpilih. Cadangan lokasi: Jakarta. |
| **Sensor** | Magnetometer (kompas peta) dan accelerometer (kontrol mini game). |
| **Misi** | Tiga misi per negara: **Trivia** (15 detik/soal), **Kuliner & Budaya** (kartu), **Mini game Tangkap Koin** (opsional). Penilaian dilakukan server. |
| **Mini game** | *Tangkap Koin*: miringkan HP untuk menggerakkan keranjang, 20 detik, target 100. |
| **Pemandu AI (LLM)** | Chat dan soal latihan dengan Gemini lewat server, kuota harian, riwayat tersimpan lokal. |
| **Rekomendasi (AI non-LLM)** | Negara berikutnya dipilih dari skor kesulitan + jarak (`recommender.dart`). |
| **Paspor digital (blockchain)** | Tiap stempel adalah blok (`previous_hash`, `hash`, `nonce`, proof-of-work berawalan `00`). Server memverifikasi seluruh rantai. |
| **Alat Perjalanan** | Konversi mata uang (12 mata uang, kurs di-cache offline) dan konversi waktu **WIB, WITA, WIT, London** (otomatis GMT/BST). |
| **Profil** | Foto profil (kamera/galeri, per akun), ubah nama tampilan, statistik progres dan koin. |
| **Kesan dan Saran** | Kesan dan saran untuk mata kuliah Pemrograman Aplikasi Mobile (tambah, lihat, hapus). |
| **Notifikasi** | Notifikasi lokal: pengingat harian (7 hari ke depan, isi mengikuti progres) dan kabar pencapaian saat negara selesai. |
| **Data lokal + online** | SQLite untuk cache negara, progres, kurs, dan riwayat chat; Supabase sebagai sumber data online. |

---

## Tangkapan Layar

Letakkan gambar di `docs/screenshots/` lalu sesuaikan nama berkas berikut.

| Splash | Login | Eksplorasi | Detail Negara |
|:--:|:--:|:--:|:--:|
| ![Splash](docs/screenshots/01-splash.png) | ![Login](docs/screenshots/02-login.png) | ![Eksplorasi](docs/screenshots/03-eksplorasi.png) | ![Detail](docs/screenshots/04-detail-negara.png) |

| Misi | Trivia | Mini Game | Pemandu AI |
|:--:|:--:|:--:|:--:|
| ![Misi](docs/screenshots/05-misi.png) | ![Trivia](docs/screenshots/06-trivia.png) | ![Mini game](docs/screenshots/07-minigame.png) | ![Pemandu](docs/screenshots/08-pemandu.png) |

| Paspor | Alat Perjalanan | Profil | Kesan dan Saran |
|:--:|:--:|:--:|:--:|
| ![Paspor](docs/screenshots/09-paspor.png) | ![Alat](docs/screenshots/10-alat-perjalanan.png) | ![Profil](docs/screenshots/11-profil.png) | ![Kesan](docs/screenshots/12-kesan-saran.png) |

---

## Teknologi

| Kebutuhan | Paket / layanan |
|---|---|
| Framework | Flutter, Dart SDK `>=3.3.0 <4.0.0` |
| State management | `provider` |
| Backend | Supabase (Edge Function `auth` + REST) lewat `supabase_flutter` dan `http` |
| Penyimpanan aman | `flutter_secure_storage` |
| Biometrik | `local_auth` |
| Database lokal | `sqflite`, `shared_preferences`, `path_provider` |
| Peta dan LBS | `flutter_map`, `latlong2`, `geolocator` |
| Sensor | `flutter_compass` (magnetometer), `sensors_plus` (accelerometer) |
| Notifikasi | `flutter_local_notifications`, `timezone` |
| Media | `image_picker` |
| UI | `google_fonts` (Sora untuk judul, DM Sans untuk isi) |
| Tooling | `flutter_native_splash`, `flutter_launcher_icons`, `flutter_lints` |

---

## Arsitektur

```
┌──────────────────────────── Aplikasi Flutter ────────────────────────────┐
│  Halaman (features/*)  ──►  Repository  ──►  Service / Database lokal    │
│   login, explore,            AuthRepository     LocationService (GPS)     │
│   mission, guide,            CountryRepository  CompassService            │
│   passport, tools,           MissionRepository  CurrencyService           │
│   profile, feedback          GuideRepository    NotificationService       │
│                              PassportRepository SecureStorage, SQLite     │
└───────────────┬───────────────────────────────┬───────────────────────────┘
                │ HTTPS                         │ HTTPS (GET, tanpa key)
                ▼                               ▼
   Supabase Edge Function `auth`        Wikipedia · Open-Meteo · Frankfurter
   (login, misi, paspor, Gemini, ...)   OpenStreetMap (tile peta)
                │
                ▼
        Database Supabase
```

Aturan utama: **halaman tidak memanggil server langsung**; semua akses data lewat repository.
Penilaian misi, verifikasi blockchain, dan pemanggilan Gemini (beserta API key-nya) hanya ada di server.

---

## Struktur Folder

```
lib/
├── main.dart, app.dart, routes.dart
├── core/
│   ├── config/        app_config.dart            # URL/kunci Supabase, mode mock
│   ├── data/          currencies.dart            # daftar 12 mata uang
│   ├── database/      app_database.dart          # SQLite (versi 3)
│   ├── services/      location, compass, currency, weather, wikipedia,
│   │                  biometric, secure_storage, profile (foto)
│   ├── theme/         app_colors.dart, app_theme.dart
│   ├── utils/         geo_utils, format_utils, paint_utils
│   └── widgets/       tombol, text field, logo
└── features/
    ├── splash/        splash_page, globe_painter
    ├── auth/          login, register, auth_repository, login_controller
    ├── shell/         main_shell, floating_nav_bar
    ├── explore/       peta, pencarian, filter, rekomendasi, panel detail
    ├── mission/       hub, trivia, kuliner & budaya, mini game, hasil
    ├── guide/         Tanya Pemandu (LLM)
    ├── passport/      paspor digital (blockchain) + widgets/
    ├── tools/         Alat Perjalanan: kurs dan jam dunia
    ├── profile/       profil dan foto
    ├── feedback/      kesan dan saran
    └── notifications/ pengingat harian dan notifikasi pencapaian
```

---

## Menjalankan Aplikasi

### Prasyarat

- Flutter SDK dengan Dart `>=3.3.0`
- Android Studio / Xcode (untuk emulator atau perangkat nyata)
- Koneksi internet (kecuali mode mock)
- Untuk uji sensor dan biometrik: **perangkat nyata** (emulator tidak memiliki magnetometer dan biometrik sungguhan)

### Langkah

```bash
git clone https://github.com/marz696/wandergeo.git
cd wandergeo

flutter pub get

# (jika nama aplikasi/izin platform belum terpasang)
# izin: internet, biometrik, lokasi; nama "WanderGeo"; FlutterFragmentActivity
dart run tool/setup_platform.dart

# ikon aplikasi dan splash bawaan OS
dart run flutter_launcher_icons
dart run flutter_native_splash:create

flutter run
```

Jika ikon atau nama lama masih muncul di emulator: hapus aplikasinya, lalu `flutter clean && flutter run`.

### Konfigurasi Supabase

Nilai bawaan di `lib/core/config/app_config.dart` sudah menunjuk ke project Supabase WanderGeo.
Untuk memakai project sendiri:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<publishable-key>
```

atau simpan di berkas dan pakai `--dart-define-from-file=env.json`.

### Mode mock (demo UI tanpa internet)

```bash
flutter run --dart-define=USE_MOCK=true
```

Mode ini mensimulasikan login (password minimal 6 karakter) dan hanya membuka tampilan.
Misi, paspor, Pemandu AI, dan kesan/saran **membutuhkan server** sehingga tidak berfungsi di mode mock.

---

## Backend (Supabase Edge Function)

Seluruh aksi aplikasi memakai satu endpoint:

```
POST {SUPABASE_URL}/functions/v1/auth
Body: { "action": "<nama>", "token": "<token sesi>", ... }
```

| Action | Fungsi |
|---|---|
| `register`, `login`, `me`, `logout` | Pendaftaran, masuk, validasi, dan akhiri sesi |
| `profile`, `update_profile`, `progress` | Data akun + statistik, ubah nama, progres per negara |
| `country_missions`, `mission_content`, `submit_mission` | Daftar misi, soal/kartu, kirim jawaban (dinilai server) |
| `passport` | Rantai blok paspor + hasil verifikasi |
| `guide_quota`, `guide_chat`, `guide_quiz` | Kuota harian, chat LLM, soal latihan |
| `feedback_list`, `feedback_save`, `feedback_delete` | Kesan dan saran |

Daftar negara dibaca langsung dari REST: `GET /rest/v1/countries`.
Tabel yang dirujuk kode: `users`, `countries`, `user_progress`, `feedbacks`.

> Kode Edge Function tidak termasuk di repositori ini. Jika Anda membuat project Supabase sendiri,
> fungsi `auth` harus mengimplementasikan seluruh action di atas dan membaca token sesi dari body.

---

## Database Lokal (SQLite)

Berkas `wandergeo.db`, versi skema **3** (`lib/core/database/app_database.dart`).

| Tabel | Kegunaan |
|---|---|
| `exchange_rates` | Cache kurs terhadap USD (kedaluwarsa 6 jam) |
| `countries` | Salinan tabel `countries` Supabase untuk mode offline |
| `user_progress` | Status dan skor terbaik per pengguna per negara |
| `chat_messages` | Riwayat percakapan Pemandu per akun dan per negara |

Pola pemuatan data: **SQLite dulu (cepat, bisa offline), lalu sinkron dari Supabase**.
Bila SQLite kosong dan offline, dipakai data awal `country_seed.dart`.

---

## API Eksternal

| Layanan | Dipakai untuk | Catatan |
|---|---|---|
| OpenStreetMap tile | Peta | Atribusi "© OpenStreetMap contributors" wajib tampil; tile publik hanya untuk pemakaian ringan |
| Wikipedia REST (bahasa Indonesia) | Ringkasan dan foto negara | Wajib mengirim `User-Agent` |
| Open-Meteo | Cuaca ibukota | Gratis, tanpa key, non-komersial; cache 15 menit |
| Frankfurter v2 | Kurs mata uang | Gratis, tanpa key; cache 6 jam di SQLite |
| Gemini (via server) | Pemandu AI | API key hanya di server |

---

## Alur Aplikasi

```
Splash OS ─► SplashPage ─► LoginPage ─► (animasi sukses) ─► MainShell
                              │  ▲
              biometrik ──────┘  └── RegisterPage

MainShell (bottom navigation, 5 tab):
  Eksplorasi │ Paspor Digital │ Profil │ Kesan dan Saran │ Logout (dialog)

Eksplorasi ─► Detail negara ─► Misi (Trivia · Kuliner & Budaya · Mini game)
          ├─► Tanya Pemandu (LLM)
          └─► Alat Perjalanan (kurs + jam dunia)
```

Negara dengan tingkat kesulitan 1 terbuka sejak awal. Menyelesaikan semua misi wajib
(Trivia, Kuliner & Budaya) menyelesaikan negara, menambah blok ke paspor, dan dapat membuka negara lain.

---

## Pemetaan Kriteria Tugas

| Kriteria | Implementasi |
|---|---|
| Konsep projek akhir | WanderGeo — geografi ASEAN dan UK bergamifikasi |
| Login terenkripsi + session (tanpa Firebase) | Edge Function `auth` + hash di server; token di `flutter_secure_storage` |
| Login biometrik | `local_auth` (`BiometricService`, `LoginController`) |
| Database lokal dan online | SQLite (`sqflite`) + Supabase |
| Web service/API dan LBS | Edge Function, REST, Wikipedia, Open-Meteo, Frankfurter; `geolocator` + haversine |
| Bottom navigation: profil (gambar), kesan dan saran PAM, logout | `MainShell` + `FloatingNavBar` |
| Konversi mata uang (≥3) dan waktu (WIB, WIT, WITA, London) | `CurrencyCard`, `WorldTimeCard` |
| Minimal 2 sensor | Magnetometer (kompas) + accelerometer (mini game) |
| AI dan LLM | `recommender.dart` + Gemini (Tanya Pemandu) |
| Mini game | Tangkap Koin |
| Pencarian dan pemilihan | Pencarian, filter, urut, pengalih wilayah di Eksplorasi |
| Notifikasi mobile | `flutter_local_notifications` (pengingat harian + pencapaian) |
| Blockchain sederhana | Paspor berupa rantai blok dengan proof-of-work |

---

## Catatan Keamanan

- Kunci `sb_publishable_...` / anon di aplikasi memang dirancang untuk publik; akses data dijaga RLS dan Edge Function.
  **Jangan pernah** menaruh `service_role` key atau API key Gemini di aplikasi.
- Password tidak disimpan di perangkat. Hanya token sesi dan data akun ringkas yang disimpan di Secure Storage.
- Penilaian misi dan verifikasi rantai dilakukan di server sehingga tidak bisa dipalsukan dari aplikasi.

---

## Pemecahan Masalah

| Gejala | Penyebab / solusi |
|---|---|
| Notifikasi tidak pernah muncul | Pastikan drawable `ic_stat_wandergeo` ada di `android/app/src/main/res/`, izin notifikasi diberikan (Android 13+), dan uji lewat *Pengaturan Notifikasi → Kirim notifikasi uji*. |
| Biometrik "tidak ada sesi" | Login dulu dengan password dan **Ingat saya** aktif; biometrik hanya membuka sesi tersimpan. |
| Kompas diam | Emulator tidak punya magnetometer; uji di HP asli. |
| Keranjang mini game bergerak terbalik | Ubah `_tiltSign` (1 ↔ -1) di `minigame_page.dart`. |
| "Tidak dapat terhubung ke server" | Periksa internet dan nilai `SUPABASE_URL` / `SUPABASE_ANON_KEY`. |
| Kurs belum tersedia | Sambungkan internet sekali agar kurs terunduh dan tersimpan di SQLite. |

---

## Keterbatasan

- Fitur yang bergantung pada server (misi, paspor, Pemandu AI, kesan dan saran) tidak bekerja offline.
- Kuota Pemandu AI dibatasi per hari per pengguna.
- Tile OpenStreetMap publik tidak untuk lalu lintas tinggi.
- Foto profil disimpan lokal per akun (di web hanya di memori).
- Notifikasi bersifat lokal dan dijadwalkan tidak eksak (dapat tertunda beberapa menit).

---

## Pembuat

**Damar Nugroho** - 124240073
**Azhicry Vernando Etsria Putra** - 124240069
Dosen pengampu: [Nama Dosen]

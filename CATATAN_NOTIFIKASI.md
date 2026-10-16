# Update: Notifikasi (lokal)

1. Timpa file di zip ini ke proyekmu (struktur folder sama).
   Catatan: `profile_page.dart` dan file Android/iOS adalah file yang sudah ada; perubahannya kecil.
   Bila kamu atau temanmu sudah mengubahnya, gabungkan manual (lihat ringkasan di bawah).
2. `flutter pub get`. Paket baru: flutter_local_notifications ^22.3.2, timezone, shared_preferences.
   Paket notifikasi ini mensyaratkan Flutter 3.38.1 ke atas dan AGP 8.11.1 ke atas (proyekmu memakai 9.1.0).
3. `flutter run`. Build Android pertama bisa lebih lama.

## Perubahan di file yang sudah ada
- pubspec.yaml: 3 paket baru.
- android/app/build.gradle.kts: `isCoreLibraryDesugaringEnabled = true` + `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")`.
- android/app/src/main/AndroidManifest.xml: izin POST_NOTIFICATIONS, RECEIVE_BOOT_COMPLETED + dua `<receiver>` notifikasi terjadwal.
- android/app/src/main/res: ikon notifikasi `drawable/ic_stat_wandergeo.xml` dan `raw/keep.xml`.
- ios/Runner/AppDelegate.swift: `UNUserNotificationCenter.current().delegate = self` agar notifikasi tampil saat app terbuka.
- lib/features/explore/explore_page.dart: jadwalkan ulang pengingat + ajakan aktivasi sekali.
- lib/features/mission/mission_result_page.dart: notifikasi saat negara selesai.
- lib/features/profile/profile_page.dart: menu "Notifikasi" (impor + satu `_SettingTile`).

## Cara menguji
- Profil > Notifikasi > "Kirim notifikasi uji" (muncul langsung).
- Aktifkan pengingat, atur jam 2-3 menit dari sekarang, tutup aplikasi, tunggu.
  Waktu bisa tertunda beberapa menit (mode hemat daya, tidak memakai alarm eksak).
- Selesaikan trivia dan Kuliner & Budaya sebuah negara: notifikasi "negara selesai" muncul.
- Android 13+: izin diminta saat kamu menekan Aktifkan.

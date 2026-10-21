# Terjemah Kamera: cara memasang

File baru di zip ini tinggal disalin ke projek dengan struktur folder yang sama.
Tidak ada file lamamu yang ditimpa. Perubahan di file lama hanya empat tempat kecil di bawah.

## File baru

lib/core/services/ocr_service.dart
lib/core/services/translate_service.dart
lib/features/translate/translate_page.dart
lib/features/translate/data/translate_history_repository.dart
lib/features/translate/widgets/scan_painters.dart
lib/features/translate/widgets/translate_entry_tile.dart
lib/features/translate/widgets/translate_history_sheet.dart

## 1. pubspec.yaml

Tambahkan dua baris ini di bagian `dependencies:` lalu jalankan `flutter pub get`.

    google_mlkit_text_recognition: ^0.16.0
    google_mlkit_translation: ^0.14.0

## 2. lib/features/tools/alat_perjalanan_page.dart

a. Tambahkan dua import di bagian atas file.

    import 'package:flutter/foundation.dart' show kIsWeb;
    import '../translate/widgets/translate_entry_tile.dart';

b. Ganti blok `_stag` (jumlah item jadi 4 dan jedanya dikecilkan, kalau tidak,
   animasi akan error karena Interval melewati 1.0).

    late final List<Animation<double>> _stag = List.generate(4, (i) {
      final start = i * .15;
      return CurvedAnimation(
        parent: _enter,
        curve: Interval(start, start + .5, curve: Curves.easeOutCubic),
      );
    });

c. Ganti teks subjudul `'Kurs mata uang dan waktu dunia'` menjadi:

    'Kurs, waktu dunia, dan terjemah kamera'

d. Tepat setelah baris `_reveal(2, const WorldTimeCard()),` tambahkan:

    if (!kIsWeb) ...[
      const SizedBox(height: 14),
      _reveal(3, const TranslateEntryTile()),
    ],

## 3. iOS (lewati bila hanya menguji di Android)

ML Kit butuh iOS 15.5 ke atas. Di `ios/Runner.xcodeproj/project.pbxproj`
ganti tiga baris `IPHONEOS_DEPLOYMENT_TARGET = 15.0;` menjadi `15.5;`.
Jika ada `ios/Podfile`, pastikan barisnya `platform :ios, '15.5'`.

## 4. Menjalankan

Jalankan `flutter pub get`, lalu `flutter run` di HP sungguhan.
Build pertama lebih lama karena ML Kit ikut dikompilasi.
Fitur ini tidak jalan di Flutter Web, karena itu tombolnya disembunyikan di sana.

## Cara memakai dan menguji

1. Buka Eksplorasi, ketuk Alat Perjalanan, lalu ketuk Terjemah Kamera.
2. Pilih bahasa pada foto, misalnya Inggris.
3. Ketuk Ambil foto atau Dari galeri.
4. Pemakaian pertama mengunduh model bahasa (perlu internet), setelah itu bisa offline.
5. Ketuk salah satu hasil untuk menyorot bagian teksnya pada foto.
6. Riwayat tersimpan di SQLite dan bisa dilihat lewat ikon jam di pojok kanan atas.

# Update: Misi (trivia 20 soal, kuliner & budaya, mini game)

Urutan pemasangan:

1. SUPABASE > SQL Editor: jalankan `supabase/migrations/002_misi.sql`
   (aman dijalankan ulang; memuat 36 misi, 240 soal, 48 kartu budaya).
2. SUPABASE > Edge Functions > `auth`: tempel ulang isi `supabase/functions/auth/index.ts`, Deploy.
   (Verify JWT tetap MATI.)
3. Proyek Flutter: timpa file-file di zip ini (struktur folder sama), hapus file di HAPUS_FILE.txt
   bila belum, lalu `flutter pub get` (ada paket baru: sensors_plus) dan `flutter run`.
4. Uji: Eksplorasi > pilih negara terbuka > Mulai Misi.

Catatan: arah miring accelerometer bisa terbalik di sebagian HP. Ubah `_tiltSign`
(1 atau -1) di lib/features/mission/minigame_page.dart.

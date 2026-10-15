# Update: Tanya Pemandu (Gemini)

1. GOOGLE AI STUDIO (aistudio.google.com): buat API key (gratis; tidak perlu kartu untuk tier gratis).
2. SUPABASE > SQL Editor: jalankan supabase/migrations/003_pemandu.sql.
3. SUPABASE > Edge Functions > Secrets: tambah
     GEMINI_API_KEY = (key dari langkah 1)
   Opsional:
     GEMINI_MODEL = nama model, dipisah koma bila lebih dari satu (cek daftar model di AI Studio)
     GUIDE_DAILY_LIMIT = batas pertanyaan per pengguna per hari (bawaan 10)
4. SUPABASE > Edge Functions > auth: tempel ulang supabase/functions/auth/index.ts, Deploy
   (Verify JWT tetap MATI).
5. FLUTTER: timpa file di zip ini, lalu flutter run. Tidak ada paket baru.
   Database lokal naik ke versi 3 otomatis (tabel chat_messages).
6. Uji: Eksplorasi > ikon bintang (Tanya Pemandu).

Catatan: jangan tulis data pribadi di chat. Pada tier gratis, Google dapat memakai
permintaan untuk meningkatkan produknya.

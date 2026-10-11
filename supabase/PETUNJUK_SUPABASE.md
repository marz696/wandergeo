# Menyiapkan login Supabase untuk WanderGeo

Nama menu di dashboard bisa sedikit berbeda dari tulisan di bawah.

1. **Buat proyek** di supabase.com (tanpa kartu kredit). Pilih region terdekat
   (mis. Southeast Asia / Singapore) dan simpan password database-nya.
2. **SQL Editor**: jalankan berurutan
   1. `geoquest_schema_v2.sql` (skema awal yang sudah diperbaiki; pakai ini, bukan `geoquest_schema.sql` lama)
   2. `supabase/migrations/001_auth.sql` (tabel sesi, penguncian akun, hak akses)
3. **Edge Functions** > *Deploy a new function* > lewat Editor:
   - Nama fungsi: `auth`
   - Tempel seluruh isi `supabase/functions/auth/index.ts`, lalu *Deploy*.
   - Buka pengaturan fungsi `auth` dan **matikan "Verify JWT"** (endpoint ini
     publik; kredensial diperiksa di dalam fungsi).
   - Tidak perlu mengatur secret: `SUPABASE_URL` dan `SUPABASE_SERVICE_ROLE_KEY`
     disediakan otomatis untuk fungsi yang di-host.
   - Alternatif lewat CLI: `supabase functions deploy auth --no-verify-jwt`
4. **Ambil kunci**: Project Settings > API. Salin *Project URL* dan kunci
   *anon / publishable*. JANGAN pernah memakai service role key di aplikasi.
5. Salin `dart_defines.example.json` menjadi `dart_defines.json`, isi kedua nilai,
   lalu jalankan:
   `flutter run --dart-define-from-file=dart_defines.json`
   (tambahkan `dart_defines.json` ke `.gitignore`).
6. **Uji**: daftar akun dari aplikasi, lalu cek Table Editor > `users`.
   Kolom `password_hash` harus berawalan `$2a$10$` (bcrypt), bukan password asli.

Uji cepat tanpa aplikasi:

```
curl -X POST https://<PROJECT_REF>.supabase.co/functions/v1/auth \
  -H "apikey: <ANON_KEY>" -H "Content-Type: application/json" \
  -d '{"action":"register","username":"budi","email":"budi@example.com","password":"rahasia123","full_name":"Budi"}'
```

Catatan keamanan yang bisa dijelaskan saat presentasi:
- Password di-hash **bcrypt** (cost 10) di server; tidak pernah disimpan atau dikirim balik.
- Sesi = token acak 256-bit. Di database hanya **hash SHA-256**-nya yang disimpan,
  sehingga bocornya tabel `sessions` tidak membocorkan token aktif.
- Akun dikunci 15 menit setelah 5 kali salah password.
- Tabel pengguna terkunci dari Data API (RLS + `revoke`); hanya Edge Function
  (service role) yang bisa mengaksesnya.
- Token di aplikasi disimpan di Keychain/Keystore (Secure Storage).

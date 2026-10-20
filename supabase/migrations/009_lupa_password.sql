-- ============================================================
-- 009_lupa_password.sql
-- Lupa password lewat kode verifikasi 6 digit yang dikirim ke email akun.
--
-- Kode TIDAK disimpan polos, hanya hash SHA-256 (digarami id pengguna).
-- Satu baris per pengguna: meminta kode baru menimpa kode lama.
-- Aturan (diterapkan di Edge Function `auth`): berlaku 15 menit,
-- maksimal 5 kali salah, jeda 60 detik antar permintaan.
-- ============================================================

create table if not exists public.password_resets (
  user_id    uuid primary key references public.users(id) on delete cascade,
  code_hash  text        not null,
  expires_at timestamptz not null,
  attempts   int         not null default 0,
  created_at timestamptz not null default now()
);

-- Seperti tabel sensitif lain: terkunci dari Data API, hanya Edge Function
-- (service role) yang boleh membaca dan menulis.
alter table public.password_resets enable row level security;
revoke all on public.password_resets from anon, authenticated;

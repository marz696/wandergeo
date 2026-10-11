-- =====================================================
-- WanderGeo | Migrasi 001: login mandiri (tanpa Supabase Auth)
-- Jalankan SETELAH geoquest_schema.sql, di Supabase > SQL Editor.
-- =====================================================

-- 1. Perlindungan brute force: kunci akun sementara setelah gagal berulang.
alter table public.users add column if not exists failed_attempts int not null default 0;
alter table public.users add column if not exists locked_until timestamptz;

-- 2. Username & email unik tanpa membedakan huruf besar/kecil.
create unique index if not exists users_username_lower_idx on public.users (lower(username));
create unique index if not exists users_email_lower_idx    on public.users (lower(email));

-- 3. Sesi login. Yang disimpan hanya HASH token (SHA-256), bukan token aslinya.
create table if not exists public.sessions (
  id          bigint generated always as identity primary key,
  user_id     uuid not null references public.users(id) on delete cascade,
  token_hash  text not null unique,
  created_at  timestamptz not null default now(),
  expires_at  timestamptz not null
);
create index if not exists sessions_user_idx on public.sessions (user_id);

alter table public.sessions enable row level security;  -- tanpa policy = terkunci untuk anon

-- 4. Data pengguna tidak boleh disentuh lewat Data API (hanya Edge Function
--    dengan service role yang boleh).
revoke all on public.users, public.sessions, public.user_progress,
              public.passport_stamps, public.feedbacks
  from anon, authenticated;

-- 5. Data referensi boleh dibaca publik. Grant eksplisit karena Supabase
--    mengubah akses default Data API (proyek lama terdampak sejak 30 Okt 2026).
grant select on public.countries, public.missions, public.quiz_questions
  to anon, authenticated;
grant select on public.leaderboard to anon, authenticated;

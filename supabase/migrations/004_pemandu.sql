-- =====================================================
-- WanderGeo | Migrasi 003: Tanya Pemandu (LLM)
-- Jalankan SETELAH 002_misi.sql. Aman dijalankan ulang.
-- =====================================================

-- Pemakaian harian per pengguna (pembatas kuota supaya kuota gratis API tidak habis).
create table if not exists public.guide_usage (
  user_id uuid not null references public.users(id) on delete cascade,
  day     date not null,
  count   int  not null default 0 check (count >= 0),
  primary key (user_id, day)
);

alter table public.guide_usage enable row level security;
revoke all on public.guide_usage from anon, authenticated;

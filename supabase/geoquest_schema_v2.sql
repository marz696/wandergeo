-- =====================================================
-- WanderGeo (dulu GeoQuest)  |  Skema Supabase (PostgreSQL)  |  v2 (diperbaiki)
-- Cakupan: ASEAN (11 negara) + United Kingdom
-- Jalankan di Supabase > SQL Editor
-- =====================================================

-- 1. USERS (autentikasi mandiri, non-Supabase Auth)
create table if not exists public.users (
  id            uuid primary key default gen_random_uuid(),
  username      text not null unique,
  email         text not null unique,
  password_hash text not null,              -- hasil bcrypt, JANGAN simpan password asli
  full_name     text,
  title         text not null default 'Petualang Pemula',  -- gelar petualang
  avatar_url    text,
  created_at    timestamptz not null default now()
);

-- 2. COUNTRIES
create table if not exists public.countries (
  code          text primary key,           -- ISO alpha-2, mis. 'MY'
  name          text not null,
  capital       text not null,
  language      text,
  population    bigint,                     -- isi dari sumber resmi (BPS/World Bank)
  flag_url      text,
  latitude      double precision not null,  -- koordinat ibukota (untuk haversine)
  longitude     double precision not null,
  region        text not null check (region in ('ASEAN', 'UK')),
  timezone      text not null,              -- nama zona IANA, mis. 'Asia/Kuala_Lumpur'
  currency_code text not null,              -- mis. 'MYR'
  difficulty    smallint not null default 1 check (difficulty between 1 and 3)
);

-- 3. MISSIONS
create table if not exists public.missions (
  id            bigint generated always as identity primary key,
  country_code  text not null references public.countries(code) on delete cascade,
  type          text not null check (type in ('trivia', 'kuliner_budaya', 'minigame')),
  title         text not null,
  description   text,
  reward_coins  int not null default 10 check (reward_coins >= 0),
  unique (country_code, type)             -- satu misi per jenis per negara
);

-- 4. QUIZ_QUESTIONS
create table if not exists public.quiz_questions (
  id             bigint generated always as identity primary key,
  mission_id     bigint not null references public.missions(id) on delete cascade,
  question       text not null,
  option_a       text not null,
  option_b       text not null,
  option_c       text not null,
  option_d       text not null,
  correct_option char(1) not null check (correct_option in ('A', 'B', 'C', 'D')),
  source         text not null default 'manual' check (source in ('manual', 'ai'))
);

-- 5. USER_PROGRESS (status negara di peta: terkunci / terbuka / selesai)
create table if not exists public.user_progress (
  user_id       uuid not null references public.users(id) on delete cascade,
  country_code  text not null references public.countries(code) on delete cascade,
  status        text not null default 'terkunci' check (status in ('terkunci', 'terbuka', 'selesai')),
  best_score    int not null default 0 check (best_score >= 0),
  updated_at    timestamptz not null default now(),
  primary key (user_id, country_code)
);

-- 6. PASSPORT_STAMPS (ledger blockchain stempel paspor)
create table if not exists public.passport_stamps (
  id            bigint generated always as identity primary key,
  user_id       uuid not null references public.users(id) on delete cascade,
  block_index   int not null,               -- 0 = genesis block
  country_code  text references public.countries(code),  -- NULL hanya untuk genesis block (index 0)
  mission_id    bigint references public.missions(id),
  score         int not null default 0 check (score >= 0),
  timestamp     timestamptz not null default now(),
  previous_hash text not null,              -- '0' untuk genesis block
  hash          text not null,              -- SHA-256 dari (index+timestamp+data+previous_hash+nonce)
  nonce         bigint not null default 0,
  unique (user_id, block_index),
  check (block_index = 0 or country_code is not null)
);

-- 7. FEEDBACKS (menu Kesan & Saran)
create table if not exists public.feedbacks (
  id          bigint generated always as identity primary key,
  user_id     uuid not null references public.users(id) on delete cascade,
  impression  text not null,                -- kesan
  suggestion  text,                         -- saran
  created_at  timestamptz not null default now()
);

-- Index untuk kolom foreign key
create index if not exists missions_country_idx       on public.missions (country_code);
create index if not exists quiz_questions_mission_idx on public.quiz_questions (mission_id);
create index if not exists feedbacks_user_idx         on public.feedbacks (user_id);

-- 8. LEADERBOARD (view: hanya menampilkan data publik)
create or replace view public.leaderboard as
select
  u.username,
  u.title,
  coalesce(sum(p.best_score), 0)::int                    as total_score,
  count(*) filter (where p.status = 'selesai')::int      as negara_selesai
from public.users u
left join public.user_progress p on p.user_id = u.id
group by u.id, u.username, u.title
order by total_score desc;

-- =====================================================
-- ROW LEVEL SECURITY
-- Karena login mandiri (bukan Supabase Auth), auth.uid() tidak tersedia.
-- Strategi: tabel data user dikunci total (tanpa policy untuk anon);
-- akses dilakukan lewat Edge Function memakai service role key.
-- Data referensi (negara, misi, soal) boleh dibaca publik.
-- =====================================================
alter table public.users            enable row level security;
alter table public.countries        enable row level security;
alter table public.missions         enable row level security;
alter table public.quiz_questions   enable row level security;
alter table public.user_progress    enable row level security;
alter table public.passport_stamps  enable row level security;
alter table public.feedbacks        enable row level security;

drop policy if exists "public read countries" on public.countries;
create policy "public read countries" on public.countries
  for select using (true);
drop policy if exists "public read missions" on public.missions;
create policy "public read missions" on public.missions
  for select using (true);
drop policy if exists "public read quiz_questions" on public.quiz_questions;
create policy "public read quiz_questions" on public.quiz_questions
  for select using (true);

grant select on public.leaderboard to anon, authenticated;

-- =====================================================
-- DATA AWAL: 12 NEGARA
-- (population & flag_url diisi manual dari sumber terpercaya)
-- =====================================================
insert into public.countries
  (code, name, capital, language, latitude, longitude, region, timezone, currency_code, difficulty)
values
  ('ID', 'Indonesia',      'Jakarta',             'Bahasa Indonesia',                -6.2088, 106.8456, 'ASEAN', 'Asia/Jakarta',       'IDR', 1),
  ('MY', 'Malaysia',       'Kuala Lumpur',        'Bahasa Melayu',                    3.1390, 101.6869, 'ASEAN', 'Asia/Kuala_Lumpur',  'MYR', 1),
  ('SG', 'Singapura',      'Singapura',           'Inggris, Melayu, Mandarin, Tamil', 1.3521, 103.8198, 'ASEAN', 'Asia/Singapore',     'SGD', 1),
  ('TH', 'Thailand',       'Bangkok',             'Thai',                            13.7563, 100.5018, 'ASEAN', 'Asia/Bangkok',       'THB', 2),
  ('VN', 'Vietnam',        'Hanoi',               'Vietnam',                         21.0285, 105.8542, 'ASEAN', 'Asia/Ho_Chi_Minh',   'VND', 2),
  ('PH', 'Filipina',       'Manila',              'Filipino, Inggris',               14.5995, 120.9842, 'ASEAN', 'Asia/Manila',        'PHP', 2),
  ('BN', 'Brunei',         'Bandar Seri Begawan', 'Bahasa Melayu',                    4.9031, 114.9398, 'ASEAN', 'Asia/Brunei',        'BND', 2),
  ('KH', 'Kamboja',        'Phnom Penh',          'Khmer',                           11.5564, 104.9282, 'ASEAN', 'Asia/Phnom_Penh',    'KHR', 3),
  ('LA', 'Laos',           'Vientiane',           'Lao',                             17.9757, 102.6331, 'ASEAN', 'Asia/Vientiane',     'LAK', 3),
  ('MM', 'Myanmar',        'Naypyidaw',           'Burma',                           19.7633,  96.0785, 'ASEAN', 'Asia/Yangon',        'MMK', 3),
  ('TL', 'Timor Leste',    'Dili',                'Tetum, Portugis',                 -8.5569, 125.5603, 'ASEAN', 'Asia/Dili',          'USD', 3),
  ('GB', 'Inggris Raya',   'London',              'Inggris',                         51.5074,  -0.1278, 'UK',    'Europe/London',      'GBP', 2)
on conflict (code) do nothing;

-- =====================================================
-- OTOMATISASI
-- =====================================================

-- Pengguna baru otomatis mendapat status awal tiap negara:
-- tingkat kesulitan 1 = terbuka, sisanya terkunci.
create or replace function public.seed_user_progress()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.user_progress (user_id, country_code, status)
  select new.id, c.code,
         case when c.difficulty = 1 then 'terbuka' else 'terkunci' end
  from public.countries c
  on conflict do nothing;
  return new;
end;
$$;

drop trigger if exists users_seed_progress on public.users;
create trigger users_seed_progress
  after insert on public.users
  for each row execute function public.seed_user_progress();

-- updated_at pada user_progress diperbarui otomatis.
create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists user_progress_touch on public.user_progress;
create trigger user_progress_touch
  before update on public.user_progress
  for each row execute function public.touch_updated_at();

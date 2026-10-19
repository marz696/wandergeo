-- ============================================================
-- 008_koin_visa_hint.sql
-- Penggunaan koin: Visa Cepat (buka negara terkunci) dan Petunjuk Trivia.
-- Syarat: 007_hint_trivia.sql sudah dijalankan (kolom quiz_questions.hint).
--
-- Semua perubahan saldo koin dilakukan ATOMIK di database. Fungsi di bawah
-- mengunci baris pengguna (FOR UPDATE) sehingga dua permintaan bersamaan
-- tidak bisa membelanjakan koin dua kali atau saling menimpa.
-- ============================================================

-- 1. Petunjuk yang sudah dibeli pada percobaan trivia yang sedang berjalan.
--    Dihapus saat jawaban dikirim (submit_mission), jadi tiap percobaan
--    harus membeli ulang. Soal yang ada di sini kehilangan bonus kecepatan.
create table if not exists public.trivia_hints (
  user_id     uuid   not null references public.users(id) on delete cascade,
  question_id bigint not null references public.quiz_questions(id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (user_id, question_id)
);
alter table public.trivia_hints enable row level security;
revoke all on public.trivia_hints from anon, authenticated;

-- 2. Tambah koin secara atomik (menggantikan baca-lalu-tulis di Edge Function).
create or replace function public.add_coins(p_user uuid, p_amount int)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare v int;
begin
  update public.users set coins = coins + p_amount
  where id = p_user
  returning coins into v;
  return v;
end $$;

-- 3. Visa Cepat: buka satu negara terkunci dengan koin.
--    Harga = p_base x tingkat kesulitan negara. Hasil berupa JSON:
--      { ok: true, coins, price }
--      { error: 'country' | 'already' | 'coins' | 'user', coins?, price? }
create or replace function public.buy_visa(p_user uuid, p_code text, p_base int)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_coins  int;
  v_diff   smallint;
  v_status text;
  v_price  int;
begin
  select coins into v_coins from public.users where id = p_user for update;
  if not found then return jsonb_build_object('error', 'user'); end if;

  select difficulty into v_diff from public.countries where code = p_code;
  if not found then return jsonb_build_object('error', 'country'); end if;
  v_price := p_base * v_diff;

  select status into v_status from public.user_progress
  where user_id = p_user and country_code = p_code;
  -- Akun lama tanpa baris progres: hanya negara tingkat 1 yang terbuka.
  if v_status is null then
    v_status := case when v_diff = 1 then 'terbuka' else 'terkunci' end;
  end if;
  if v_status <> 'terkunci' then
    return jsonb_build_object('error', 'already', 'coins', v_coins, 'price', v_price);
  end if;
  if v_coins < v_price then
    return jsonb_build_object('error', 'coins', 'coins', v_coins, 'price', v_price);
  end if;

  update public.users set coins = coins - v_price where id = p_user returning coins into v_coins;
  insert into public.user_progress (user_id, country_code, status)
  values (p_user, p_code, 'terbuka')
  on conflict (user_id, country_code) do update set status = 'terbuka', updated_at = now();

  return jsonb_build_object('ok', true, 'coins', v_coins, 'price', v_price);
end $$;

-- 4. Petunjuk trivia: potong koin dan catat pembelian.
--    Bila soal itu sudah dibeli pada percobaan ini, tidak dipotong lagi.
--      { ok: true, charged: true|false, coins }
--      { error: 'coins' | 'user', coins? }
create or replace function public.buy_hint(p_user uuid, p_question bigint, p_price int)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare v_coins int;
begin
  select coins into v_coins from public.users where id = p_user for update;
  if not found then return jsonb_build_object('error', 'user'); end if;

  if exists (select 1 from public.trivia_hints where user_id = p_user and question_id = p_question) then
    return jsonb_build_object('ok', true, 'charged', false, 'coins', v_coins);
  end if;
  if v_coins < p_price then
    return jsonb_build_object('error', 'coins', 'coins', v_coins);
  end if;

  update public.users set coins = coins - p_price where id = p_user returning coins into v_coins;
  insert into public.trivia_hints (user_id, question_id) values (p_user, p_question);
  return jsonb_build_object('ok', true, 'charged', true, 'coins', v_coins);
end $$;

-- 5. Fungsi hanya boleh dipanggil dari Edge Function (service role).
revoke all on function public.add_coins(uuid, int) from public, anon, authenticated;
revoke all on function public.buy_visa(uuid, text, int) from public, anon, authenticated;
revoke all on function public.buy_hint(uuid, bigint, int) from public, anon, authenticated;
grant execute on function public.add_coins(uuid, int) to service_role;
grant execute on function public.buy_visa(uuid, text, int) to service_role;
grant execute on function public.buy_hint(uuid, bigint, int) to service_role;

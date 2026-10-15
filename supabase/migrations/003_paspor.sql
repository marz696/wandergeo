-- =====================================================
-- WanderGeo | Migrasi 003: Paspor Digital (blockchain sederhana)
-- Jalankan SETELAH 002_misi.sql. Aman dijalankan ulang.
-- =====================================================

-- 1. Satu stempel per negara per pengguna (genesis, country_code NULL, dikecualikan).
create unique index if not exists passport_stamps_user_country_uni
  on public.passport_stamps (user_id, country_code)
  where country_code is not null;

-- 2. Append-only: blok yang sudah ditulis tidak boleh diubah atau dihapus lewat
--    jalur normal. (Pemilik database tetap bisa menonaktifkan trigger; karena itu
--    rantai disebut "tamper-evident": perubahan DIKETAHUI lewat verifikasi hash,
--    bukan mustahil dilakukan.)
create or replace function public.passport_stamps_immutable()
returns trigger language plpgsql as $$
begin
  if current_setting('wandergeo.allow_tamper', true) = 'on' then
    return coalesce(new, old);   -- hanya untuk demo di presentasi
  end if;
  raise exception 'passport_stamps bersifat append-only';
end $$;

drop trigger if exists passport_stamps_no_update on public.passport_stamps;
create trigger passport_stamps_no_update
  before update or delete on public.passport_stamps
  for each row execute function public.passport_stamps_immutable();

-- 3. Hanya Edge Function (service role) yang boleh menyentuh tabel ini.
alter table public.passport_stamps enable row level security;
revoke all on public.passport_stamps from anon, authenticated;

-- Kesan & Saran versi baru: rating wajah (1-5) + chip pilihan + satu kotak teks.
--
-- - rating : 1 (sangat kecewa) sampai 5 (sangat senang). Baris lama = NULL.
-- - tags   : pilihan chip. Daftar yang sah dijaga di Edge Function `auth`.
-- - impression sekarang boleh kosong, karena teks tambahan bersifat opsional.
--
-- Tabel `feedbacks` tetap terkunci dari Data API (tanpa grant ke anon dan
-- authenticated); semua akses lewat Edge Function (service role).

alter table public.feedbacks
  add column if not exists rating smallint
    check (rating between 1 and 5);

alter table public.feedbacks
  add column if not exists tags text[] not null default '{}';

alter table public.feedbacks
  alter column impression drop not null;

-- Daftar "semua kesan" diurutkan terbaru / rating tertinggi.
create index if not exists feedbacks_created_idx on public.feedbacks (created_at desc);
create index if not exists feedbacks_rating_idx  on public.feedbacks (rating desc nulls last);
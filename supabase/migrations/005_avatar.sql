-- Foto profil: disimpan di Supabase Storage (bucket publik `avatars`), dan
-- link-nya ditulis ke kolom users.avatar_url oleh Edge Function `auth`.
--
-- Bucket dibuat PUBLIK agar foto bisa dimuat lewat link biasa (Image.network).
-- Yang bisa MENULIS hanya Edge Function (service role); tidak ada policy
-- INSERT/UPDATE/DELETE untuk anon/authenticated, jadi klien tidak bisa
-- mengunggah langsung ke bucket ini.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'avatars',
  'avatars',
  true,
  2097152, -- 2 MB
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

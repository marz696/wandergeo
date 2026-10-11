// Edge Function `auth`: register, login, me, logout.
// Autentikasi mandiri (tanpa Supabase Auth): password di-hash bcrypt, sesi
// berupa token acak yang hanya disimpan sebagai hash SHA-256 di tabel `sessions`.
//
// Deploy dengan "Verify JWT" DIMATIKAN (endpoint ini publik; kredensial
// diverifikasi di dalam fungsi):
//   supabase functions deploy auth --no-verify-jwt
// atau matikan toggle "Verify JWT" di dashboard pada halaman fungsi.

import { createClient } from "npm:@supabase/supabase-js@2";
import bcrypt from "npm:bcryptjs@2.4.3";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);

const SESSION_DAYS = 30;
const MAX_FAILS = 5;
const LOCK_MINUTES = 15;
// Dipakai agar waktu respons "username tidak ada" mirip dengan "password salah".
const DUMMY_HASH = bcrypt.hashSync("dummy-password-wandergeo", 10);

// CORS: wajib agar aplikasi yang berjalan di browser (Flutter Web) bisa memanggil
// fungsi ini. Browser mengirim permintaan OPTIONS dulu sebelum POST. Aman karena
// autentikasi memakai token di body, bukan cookie.
const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...CORS },
  });

function randomToken(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  return btoa(String.fromCharCode(...bytes))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}

async function sha256(text: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(text),
  );
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

// deno-lint-ignore no-explicit-any
const publicUser = (u: any) => ({
  id: u.id,
  username: u.username,
  email: u.email,
  full_name: u.full_name,
  title: u.title,
  avatar_url: u.avatar_url,
});

async function createSession(userId: string) {
  const token = randomToken();
  const expires = new Date(Date.now() + SESSION_DAYS * 86_400_000);
  const { error } = await supabase.from("sessions").insert({
    user_id: userId,
    token_hash: await sha256(token),
    expires_at: expires.toISOString(),
  });
  if (error) throw error;
  return { token, expires_at: expires.toISOString() };
}

// deno-lint-ignore no-explicit-any
async function register(b: any) {
  const username = String(b.username ?? "").trim().toLowerCase();
  const email = String(b.email ?? "").trim().toLowerCase();
  const password = String(b.password ?? "");
  const fullName = String(b.full_name ?? "").trim().slice(0, 60) || null;

  if (!/^[a-z0-9_]{3,20}$/.test(username)) {
    return json(400, { error: "Username 3-20 karakter: huruf kecil, angka, atau _" });
  }
  if (email.length > 120 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return json(400, { error: "Format email tidak valid" });
  }
  const pwBytes = new TextEncoder().encode(password).length;
  if (pwBytes < 8 || pwBytes > 72 || !/[A-Za-z]/.test(password) || !/\d/.test(password)) {
    return json(400, { error: "Password 8-72 karakter dan mengandung huruf serta angka" });
  }

  const { data, error } = await supabase
    .from("users")
    .insert({
      username,
      email,
      password_hash: bcrypt.hashSync(password, 10),
      full_name: fullName,
    })
    .select()
    .single();

  if (error) {
    if (error.code === "23505") {
      return json(409, {
        error: error.message.includes("email")
          ? "Email sudah terdaftar"
          : "Username sudah dipakai",
      });
    }
    throw error;
  }
  return json(201, { ...(await createSession(data.id)), user: publicUser(data) });
}

// deno-lint-ignore no-explicit-any
async function login(b: any) {
  const identifier = String(b.identifier ?? "").trim().toLowerCase();
  const password = String(b.password ?? "");
  if (!identifier || !password) {
    return json(400, { error: "Isi username/email dan password" });
  }
  const invalid = () => json(401, { error: "Username atau password salah" });

  const column = identifier.includes("@") ? "email" : "username";
  const { data: user, error } = await supabase
    .from("users")
    .select("*")
    .eq(column, identifier)
    .maybeSingle();
  if (error) throw error;

  if (!user) {
    bcrypt.compareSync(password, DUMMY_HASH);
    return invalid();
  }
  if (user.locked_until && new Date(user.locked_until) > new Date()) {
    return json(429, { error: "Terlalu banyak percobaan. Coba lagi beberapa menit lagi." });
  }
  if (!bcrypt.compareSync(password, user.password_hash)) {
    const fails = (user.failed_attempts ?? 0) + 1;
    const patch = fails >= MAX_FAILS
      ? {
        failed_attempts: 0,
        locked_until: new Date(Date.now() + LOCK_MINUTES * 60_000).toISOString(),
      }
      : { failed_attempts: fails };
    await supabase.from("users").update(patch).eq("id", user.id);
    return invalid();
  }

  await supabase.from("users").update({ failed_attempts: 0, locked_until: null }).eq("id", user.id);
  return json(200, { ...(await createSession(user.id)), user: publicUser(user) });
}

async function userFromToken(token: string) {
  if (!token) return null;
  const { data } = await supabase
    .from("sessions")
    .select("expires_at, users(*)")
    .eq("token_hash", await sha256(token))
    .maybeSingle();
  // deno-lint-ignore no-explicit-any
  const row = data as any;
  if (!row || new Date(row.expires_at) < new Date()) return null;
  return row.users;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json(405, { error: "Method not allowed" });
  // deno-lint-ignore no-explicit-any
  let body: any;
  try {
    body = await req.json();
  } catch {
    return json(400, { error: "Body harus JSON" });
  }

  try {
    switch (body.action) {
      case "register":
        return await register(body);
      case "login":
        return await login(body);
      case "me": {
        const user = await userFromToken(String(body.token ?? ""));
        return user ? json(200, { user: publicUser(user) }) : json(401, { error: "Sesi tidak valid" });
      }
      case "logout": {
        const token = String(body.token ?? "");
        if (token) {
          await supabase.from("sessions").delete().eq("token_hash", await sha256(token));
        }
        return json(200, { ok: true });
      }
      default:
        return json(400, { error: "Aksi tidak dikenal" });
    }
  } catch (e) {
    console.error(e);
    return json(500, { error: "Terjadi kesalahan server" });
  }
});
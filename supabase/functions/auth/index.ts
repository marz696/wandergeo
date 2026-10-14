// Edge Function `auth`: register, login, me, profile, update_profile, progress, country_missions, mission_content, submit_mission, logout.
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
  coins: u.coins ?? 0,
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

// Data profil: akun + ringkasan progres paspor dari tabel `user_progress`.
// Tabel itu terkunci RLS dari Data API, jadi dibaca di sini lewat service role,
// dan HANYA untuk pemilik token (id user diambil dari sesi, bukan dari body).
// deno-lint-ignore no-explicit-any
async function profile(b: any) {
  const user = await userFromToken(String(b.token ?? ""));
  if (!user) return json(401, { error: "Sesi tidak valid" });

  const { data, error } = await supabase
    .from("user_progress")
    .select("status, best_score")
    .eq("user_id", user.id);
  if (error) throw error;

  const rows = data ?? [];
  const count = (status: string) => rows.filter((r) => r.status === status).length;
  return json(200, {
    user: publicUser(user),
    stats: {
      selesai: count("selesai"),
      terbuka: count("terbuka"),
      terkunci: count("terkunci"),
      total: rows.length,
      total_score: rows.reduce((sum, r) => sum + (r.best_score ?? 0), 0),
    },
  });
}

// Ubah nama tampilan. Hanya `full_name` yang boleh diubah dari sini.
// deno-lint-ignore no-explicit-any
async function updateProfile(b: any) {
  const user = await userFromToken(String(b.token ?? ""));
  if (!user) return json(401, { error: "Sesi tidak valid" });

  const fullName = String(b.full_name ?? "").trim();
  if (fullName.length < 2 || fullName.length > 60) {
    return json(400, { error: "Nama 2-60 karakter" });
  }

  const { data, error } = await supabase
    .from("users")
    .update({ full_name: fullName })
    .eq("id", user.id)
    .select()
    .single();
  if (error) throw error;
  return json(200, { user: publicUser(data) });
}

// Progres tiap negara milik pemilik token (tabel user_progress terkunci dari
// Data API, jadi dibaca di sini lewat service role).
// deno-lint-ignore no-explicit-any
async function progress(b: any) {
  const user = await userFromToken(String(b.token ?? ""));
  if (!user) return json(401, { error: "Sesi tidak valid" });
  const { data, error } = await supabase
    .from("user_progress")
    .select("country_code, status, best_score")
    .eq("user_id", user.id);
  if (error) throw error;
  return json(200, { progress: data ?? [] });
}

// =====================================================
// MISI: daftar misi, isi misi, dan penilaian (di server, bukan di aplikasi)
// =====================================================
const PASS_RATIO = 0.6; // trivia lulus bila minimal 60% benar
const GAME_TARGET = 100; // mini game selesai bila skor >= target
const GAME_MAX = 400; // batas wajar skor mini game (dilaporkan klien)

const toRad = (d: number) => (d * Math.PI) / 180;
// deno-lint-ignore no-explicit-any
function distanceKm(a: any, b: any): number {
  const dLat = toRad(b.latitude - a.latitude);
  const dLng = toRad(b.longitude - a.longitude);
  const h = Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(a.latitude)) * Math.cos(toRad(b.latitude)) * Math.sin(dLng / 2) ** 2;
  return 2 * 6371 * Math.asin(Math.min(1, Math.sqrt(h)));
}

async function loadMission(id: unknown) {
  const mid = Number(id);
  if (!Number.isInteger(mid)) return null;
  const { data } = await supabase
    .from("missions")
    .select("id, country_code, type, reward_coins")
    .eq("id", mid)
    .maybeSingle();
  return data;
}

// Akun lama tanpa baris progres: hanya negara tingkat 1 yang terbuka.
async function countryUnlocked(userId: string, code: string): Promise<boolean> {
  const { data } = await supabase
    .from("user_progress")
    .select("status")
    .eq("user_id", userId)
    .eq("country_code", code)
    .maybeSingle();
  if (data) return data.status !== "terkunci";
  const { data: c } = await supabase.from("countries").select("difficulty").eq("code", code).maybeSingle();
  return !!c && c.difficulty === 1;
}

// deno-lint-ignore no-explicit-any
async function countryMissions(b: any) {
  const user = await userFromToken(String(b.token ?? ""));
  if (!user) return json(401, { error: "Sesi tidak valid" });
  const code = String(b.country_code ?? "").toUpperCase();
  if (!(await countryUnlocked(user.id, code))) {
    return json(403, { error: "Negara ini masih terkunci" });
  }
  const { data: ms, error } = await supabase
    .from("missions")
    .select("id, type, title, description, reward_coins")
    .eq("country_code", code)
    .order("id");
  if (error) throw error;
  // deno-lint-ignore no-explicit-any
  const ids = (ms ?? []).map((m: any) => m.id);
  // deno-lint-ignore no-explicit-any
  let rows: any[] = [];
  if (ids.length) {
    const { data } = await supabase
      .from("user_missions")
      .select("mission_id, best_score, completed")
      .eq("user_id", user.id)
      .in("mission_id", ids);
    rows = data ?? [];
  }
  return json(200, {
    // deno-lint-ignore no-explicit-any
    missions: (ms ?? []).map((m: any) => {
      // deno-lint-ignore no-explicit-any
      const r = rows.find((x: any) => x.mission_id === m.id);
      return { ...m, best_score: r?.best_score ?? 0, completed: r?.completed ?? false };
    }),
  });
}

// deno-lint-ignore no-explicit-any
async function missionContent(b: any) {
  const user = await userFromToken(String(b.token ?? ""));
  if (!user) return json(401, { error: "Sesi tidak valid" });
  const m = await loadMission(b.mission_id);
  if (!m) return json(404, { error: "Misi tidak ditemukan" });
  if (!(await countryUnlocked(user.id, m.country_code))) {
    return json(403, { error: "Negara ini masih terkunci" });
  }

  if (m.type === "trivia") {
    const { data, error } = await supabase
      .from("quiz_questions")
      .select("id, question, option_a, option_b, option_c, option_d, correct_option, explanation")
      .eq("mission_id", m.id);
    if (error) throw error;
    const qs = [...(data ?? [])];
    for (let i = qs.length - 1; i > 0; i--) { // acak urutan soal
      const j = Math.floor(Math.random() * (i + 1));
      [qs[i], qs[j]] = [qs[j], qs[i]];
    }
    return json(200, {
      mission_id: m.id,
      type: m.type,
      // deno-lint-ignore no-explicit-any
      questions: qs.map((q: any) => ({
        id: q.id,
        text: q.question,
        options: [q.option_a, q.option_b, q.option_c, q.option_d],
        correct: "ABCD".indexOf(q.correct_option),
        explanation: q.explanation ?? "",
      })),
    });
  }
  if (m.type === "kuliner_budaya") {
    const { data, error } = await supabase
      .from("culture_cards")
      .select("id, title, category, icon, fact")
      .eq("mission_id", m.id)
      .order("sort_order");
    if (error) throw error;
    return json(200, { mission_id: m.id, type: m.type, cards: data ?? [] });
  }
  return json(200, { mission_id: m.id, type: m.type, target: GAME_TARGET, seconds: 20 });
}

// Negara baru yang dibuka setelah satu negara selesai: dua negara terkunci
// terdekat dengan tingkat kesulitan <= tingkat negara yang selesai + 1.
async function unlockNext(userId: string, doneCode: string): Promise<string[]> {
  const { data: countries } = await supabase
    .from("countries")
    .select("code, difficulty, latitude, longitude");
  const { data: prog } = await supabase
    .from("user_progress")
    .select("country_code, status")
    .eq("user_id", userId);
  // deno-lint-ignore no-explicit-any
  const status = new Map((prog ?? []).map((p: any) => [p.country_code, p.status]));
  // deno-lint-ignore no-explicit-any
  const all: any[] = countries ?? [];
  const me = all.find((c) => c.code === doneCode);
  if (!me) return [];
  const locked = all.filter((c) =>
    c.code !== doneCode &&
    (status.get(c.code) ?? (c.difficulty === 1 ? "terbuka" : "terkunci")) === "terkunci"
  );
  let pool = locked.filter((c) => c.difficulty <= me.difficulty + 1);
  pool = pool.length
    ? pool.sort((a, b) => distanceKm(me, a) - distanceKm(me, b))
    : [...locked].sort((a, b) => a.difficulty - b.difficulty || distanceKm(me, a) - distanceKm(me, b));
  const picks = pool.slice(0, 2);
  if (picks.length) {
    await supabase.from("user_progress").upsert(
      picks.map((c) => ({ user_id: userId, country_code: c.code, status: "terbuka" })),
      { onConflict: "user_id,country_code" },
    );
  }
  return picks.map((c) => c.code);
}

// deno-lint-ignore no-explicit-any
async function submitMission(b: any) {
  const user = await userFromToken(String(b.token ?? ""));
  if (!user) return json(401, { error: "Sesi tidak valid" });
  const m = await loadMission(b.mission_id);
  if (!m) return json(404, { error: "Misi tidak ditemukan" });
  if (!(await countryUnlocked(user.id, m.country_code))) {
    return json(403, { error: "Negara ini masih terkunci" });
  }

  let passed = false, score = 0, correct = 0, total = 0;
  if (m.type === "trivia") {
    const { data: qs } = await supabase
      .from("quiz_questions")
      .select("id, correct_option")
      .eq("mission_id", m.id);
    // deno-lint-ignore no-explicit-any
    const key = new Map((qs ?? []).map((q: any) => [q.id, "ABCD".indexOf(q.correct_option)]));
    total = key.size;
    const answers = Array.isArray(b.answers) ? b.answers : [];
    const seen = new Set<number>();
    let streak = 0;
    for (const a of answers) {
      const qid = Number(a?.question_id);
      if (!key.has(qid) || seen.has(qid)) continue;
      seen.add(qid);
      const timeLeft = Math.max(0, Math.min(15, Math.floor(Number(a?.time_left) || 0)));
      if (Number(a?.choice) === key.get(qid)) {
        correct++;
        streak++;
        score += 10 + Math.min(5, Math.floor(timeLeft / 3)) + Math.min(5, streak - 1);
      } else {
        streak = 0;
      }
    }
    if (total === 0 || seen.size !== total) return json(400, { error: "Jawaban tidak lengkap" });
    passed = correct / total >= PASS_RATIO;
  } else if (m.type === "kuliner_budaya") {
    const { data: cards } = await supabase.from("culture_cards").select("id").eq("mission_id", m.id);
    const studied = new Set((Array.isArray(b.studied) ? b.studied : []).map(Number));
    // deno-lint-ignore no-explicit-any
    const ids: number[] = (cards ?? []).map((c: any) => c.id);
    total = ids.length;
    correct = ids.filter((id) => studied.has(id)).length;
    score = correct * 10;
    passed = total > 0 && correct === total;
  } else {
    score = Math.max(0, Math.min(GAME_MAX, Math.floor(Number(b.score) || 0)));
    total = GAME_TARGET;
    correct = score;
    passed = score >= GAME_TARGET;
  }

  const { data: prev } = await supabase
    .from("user_missions")
    .select("best_score, completed")
    .eq("user_id", user.id)
    .eq("mission_id", m.id)
    .maybeSingle();
  const firstCompletion = passed && !prev?.completed;
  // deno-lint-ignore no-explicit-any
  const row: any = {
    user_id: user.id,
    mission_id: m.id,
    best_score: Math.max(prev?.best_score ?? 0, score),
    completed: !!prev?.completed || passed,
  };
  if (firstCompletion) row.completed_at = new Date().toISOString();
  const up = await supabase.from("user_missions").upsert(row, { onConflict: "user_id,mission_id" });
  if (up.error) throw up.error;

  let coins: number = user.coins ?? 0;
  let coinsEarned = 0;
  if (firstCompletion) {
    coinsEarned = m.reward_coins;
    coins += coinsEarned;
    await supabase.from("users").update({ coins }).eq("id", user.id);
  }

  // Negara selesai bila trivia DAN kuliner & budaya sudah lulus (mini game opsional).
  const { data: cms } = await supabase.from("missions").select("id, type").eq("country_code", m.country_code);
  // deno-lint-ignore no-explicit-any
  const mids = (cms ?? []).map((x: any) => x.id);
  const { data: ums } = await supabase
    .from("user_missions")
    .select("mission_id, best_score, completed")
    .eq("user_id", user.id)
    .in("mission_id", mids);
  const done = (type: string) => {
    // deno-lint-ignore no-explicit-any
    const mm = (cms ?? []).find((x: any) => x.type === type);
    // deno-lint-ignore no-explicit-any
    return !!(ums ?? []).find((u: any) => u.mission_id === mm?.id && u.completed);
  };
  // deno-lint-ignore no-explicit-any
  const countryScore = (ums ?? []).reduce((s: number, u: any) => s + u.best_score, 0);
  const completeNow = done("trivia") && done("kuliner_budaya");
  const { data: cur } = await supabase
    .from("user_progress")
    .select("status")
    .eq("user_id", user.id)
    .eq("country_code", m.country_code)
    .maybeSingle();
  const wasDone = cur?.status === "selesai";
  const newStatus = completeNow ? "selesai" : (cur?.status ?? "terbuka");
  await supabase.from("user_progress").upsert(
    { user_id: user.id, country_code: m.country_code, status: newStatus, best_score: countryScore },
    { onConflict: "user_id,country_code" },
  );
  const justCompleted = completeNow && !wasDone;
  const unlocked = justCompleted ? await unlockNext(user.id, m.country_code) : [];

  return json(200, {
    passed,
    score,
    correct,
    total,
    coins_earned: coinsEarned,
    coins,
    first_completion: firstCompletion,
    country: { code: m.country_code, status: newStatus, best_score: countryScore },
    country_completed: justCompleted,
    unlocked,
  });
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
      case "profile":
        return await profile(body);
      case "update_profile":
        return await updateProfile(body);
      case "progress":
        return await progress(body);
      case "country_missions":
        return await countryMissions(body);
      case "mission_content":
        return await missionContent(body);
      case "submit_mission":
        return await submitMission(body);
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
import '../../core/database/app_database.dart';
import '../auth/auth_repository.dart';
import 'guide_models.dart';

/// Tanya Pemandu: pertanyaan dikirim ke Edge Function `auth` (aksi guide_*),
/// yang memanggil Gemini dengan API key di server. Riwayat teks disimpan di
/// SQLite per akun dan per negara.
class GuideRepository {
  GuideRepository(this._auth);

  final AuthRepository _auth;

  /// Gemini bisa butuh beberapa detik (server mencoba maksimal dua model, masing-
  /// masing sampai 20 detik), jadi batas tunggu jauh di atas bawaan 20 detik.
  /// Bila sama dengan bawaan, aplikasi menyerah sebelum server selesai: muncul
  /// "tidak ada koneksi" padahal server masih memproses dan kuota sudah terpotong.
  static const _aiTimeout = Duration(seconds: 60);

  Future<Map<String, dynamic>> _call(
    String action,
    Map<String, dynamic> body, {
    Duration? timeout,
  }) async {
    final r = timeout == null
        ? await _auth.authed(action, body)
        : await _auth.authed(action, body, timeout: timeout);
    if (r.ok && r.data != null) return r.data!;
    final kind = r.timedOut
        ? GuideErrorKind.timeout
        : r.networkError
            ? GuideErrorKind.network
            : (r.status == 429 && r.data?['remaining'] == 0
                ? GuideErrorKind.quota
                : GuideErrorKind.other);
    throw GuideException(r.message, kind);
  }

  /// Sisa pertanyaan hari ini; null bila tidak bisa diambil.
  Future<int?> quota() async {
    try {
      final d = await _call('guide_quota', {});
      return (d['remaining'] as num).toInt();
    } on GuideException {
      return null;
    }
  }

  Future<({String reply, int remaining})> ask({
    required String countryCode,
    required String message,
    required List<GuideMessage> history,
  }) async {
    final plain = history.where((m) => !m.isError && m.quiz == null).toList();
    final tail = plain.length > 6 ? plain.sublist(plain.length - 6) : plain;
    final d = await _call(
      'guide_chat',
      {
        'country_code': countryCode,
        'message': message,
        'history': [
          for (final m in tail)
            {'role': m.role == GuideRole.user ? 'user' : 'model', 'text': m.text},
        ],
      },
      timeout: _aiTimeout,
    );
    return (reply: d['reply'] as String, remaining: (d['remaining'] as num).toInt());
  }

  Future<({GuideQuiz quiz, int remaining})> quiz(String countryCode) async {
    final d = await _call(
      'guide_quiz',
      {'country_code': countryCode},
      timeout: _aiTimeout,
    );
    return (
      quiz: GuideQuiz.fromJson(d),
      remaining: (d['remaining'] as num).toInt(),
    );
  }

  // ---------- riwayat lokal (SQLite) ----------

  Future<List<GuideMessage>> loadHistory(String userId, String code) async {
    try {
      final db = await AppDatabase.instance.db;
      final rows = await db.query(
        'chat_messages',
        where: 'user_id = ? AND country_code = ?',
        whereArgs: [userId, code],
        orderBy: 'id DESC',
        limit: 40,
      );
      return [
        for (final r in rows.reversed)
          GuideMessage(
            role: r['role'] == 'user' ? GuideRole.user : GuideRole.guide,
            text: r['text'] as String,
          ),
      ];
    } catch (_) {
      return [];
    }
  }

  Future<void> save(String userId, String code, GuideMessage m) async {
    try {
      final db = await AppDatabase.instance.db;
      await db.insert('chat_messages', {
        'user_id': userId,
        'country_code': code,
        'role': m.role == GuideRole.user ? 'user' : 'guide',
        'text': m.text,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (_) {}
  }

  Future<void> clear(String userId, String code) async {
    try {
      final db = await AppDatabase.instance.db;
      await db.delete('chat_messages',
          where: 'user_id = ? AND country_code = ?', whereArgs: [userId, code]);
    } catch (_) {}
  }
}
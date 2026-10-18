import '../../auth/auth_repository.dart';

class FeedbackException implements Exception {
  const FeedbackException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Pilihan chip. HARUS sama dengan `FEEDBACK_TAGS` di
/// supabase/functions/auth/index.ts (server menolak pilihan di luar daftar ini).
const kFeedbackTags = <String>[
  'Materi mudah dipahami',
  'Seru banget',
  'Dosen baik',
  'Tugasnya susah',
  'Tugasnya asik sekali',
  'Perlu lebih banyak latihan',
  'Perlu belajar lagi',
];

/// Label untuk rating wajah 1 sampai 5.
const kRatingLabels = <String>[
  'Sangat kecewa',
  'Kecewa',
  'Biasa saja',
  'Senang',
  'Sangat senang',
];

DateTime _parseDate(Object? v) =>
    DateTime.tryParse(v as String? ?? '')?.toLocal() ?? DateTime.now();

List<String> _parseTags(Object? v) =>
    [for (final t in (v as List?) ?? const []) t.toString()];

/// Gabungan teks tambahan (kolom `impression`) dan saran lama (`suggestion`,
/// dari kiriman sebelum desain baru), supaya data lama tetap tampil.
String _joinMessage(String? impression, String? suggestion) {
  final parts = <String>[
    if (impression != null && impression.trim().isNotEmpty) impression.trim(),
    if (suggestion != null && suggestion.trim().isNotEmpty)
      'Saran: ${suggestion.trim()}',
  ];
  return parts.join('\n');
}

/// Satu entri kesan dan saran milik pengguna.
class FeedbackEntry {
  const FeedbackEntry({
    required this.id,
    required this.rating,
    required this.tags,
    required this.message,
    required this.createdAt,
  });

  final int id;

  /// 1 sampai 5; null untuk kiriman lama yang dibuat sebelum ada rating.
  final int? rating;
  final List<String> tags;
  final String message;
  final DateTime createdAt;

  factory FeedbackEntry.fromJson(Map<String, dynamic> j) => FeedbackEntry(
        id: (j['id'] as num).toInt(),
        rating: (j['rating'] as num?)?.toInt(),
        tags: _parseTags(j['tags']),
        message: _joinMessage(j['impression'] as String?, j['suggestion'] as String?),
        createdAt: _parseDate(j['created_at']),
      );
}

/// Kiriman milik siapa saja, untuk halaman "Semua kesan & pesan".
class PublicFeedback {
  const PublicFeedback({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.rating,
    required this.tags,
    required this.message,
    required this.createdAt,
  });

  final int id;
  final String name;
  final String? avatarUrl;
  final int? rating;
  final List<String> tags;
  final String message;
  final DateTime createdAt;

  factory PublicFeedback.fromJson(Map<String, dynamic> j) => PublicFeedback(
        id: (j['id'] as num).toInt(),
        name: j['name'] as String? ?? 'Mahasiswa',
        avatarUrl: j['avatar_url'] as String?,
        rating: (j['rating'] as num?)?.toInt(),
        tags: _parseTags(j['tags']),
        message: _joinMessage(j['impression'] as String?, j['suggestion'] as String?),
        createdAt: _parseDate(j['created_at']),
      );
}

class FeedbackBoard {
  const FeedbackBoard({required this.items, required this.total});
  final List<PublicFeedback> items;
  final int total;
}

enum FeedbackSort { latest, rating }

/// Kesan dan saran disimpan di tabel `feedbacks` lewat Edge Function `auth`
/// (aksi feedback_list, feedback_all, feedback_save, feedback_delete).
class FeedbackRepository {
  FeedbackRepository(this._auth);

  final AuthRepository _auth;

  Future<Map<String, dynamic>> _call(
      String action, Map<String, dynamic> body) async {
    final r = await _auth.authed(action, body);
    if (!r.ok || r.data == null) throw FeedbackException(r.message);
    return r.data!;
  }

  /// Riwayat kiriman milik pengguna yang sedang masuk.
  Future<List<FeedbackEntry>> list() async {
    final d = await _call('feedback_list', const {});
    return [
      for (final e in (d['items'] as List?) ?? const [])
        FeedbackEntry.fromJson(Map<String, dynamic>.from(e as Map)),
    ];
  }

  /// Kiriman semua mahasiswa (maksimal 100 terbaru atau terbaik).
  Future<FeedbackBoard> listAll({FeedbackSort sort = FeedbackSort.latest}) async {
    final d = await _call('feedback_all', {
      'sort': sort == FeedbackSort.rating ? 'rating' : 'latest',
    });
    final items = [
      for (final e in (d['items'] as List?) ?? const [])
        PublicFeedback.fromJson(Map<String, dynamic>.from(e as Map)),
    ];
    return FeedbackBoard(
      items: items,
      total: (d['total'] as num?)?.toInt() ?? items.length,
    );
  }

  Future<FeedbackEntry> save({
    required int rating,
    required List<String> tags,
    required String message,
  }) async {
    final d = await _call('feedback_save', {
      'rating': rating,
      'tags': tags,
      'impression': message,
    });
    return FeedbackEntry.fromJson(Map<String, dynamic>.from(d['item'] as Map));
  }

  Future<void> delete(int id) async {
    await _call('feedback_delete', {'id': id});
  }
}

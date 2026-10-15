import '../../auth/auth_repository.dart';

class FeedbackException implements Exception {
  const FeedbackException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Satu entri kesan dan saran milik pengguna.
class FeedbackEntry {
  const FeedbackEntry({
    required this.id,
    required this.impression,
    required this.suggestion,
    required this.createdAt,
  });

  final int id;
  final String impression;
  final String? suggestion;
  final DateTime createdAt;

  factory FeedbackEntry.fromJson(Map<String, dynamic> j) => FeedbackEntry(
        id: (j['id'] as num).toInt(),
        impression: j['impression'] as String? ?? '',
        suggestion: j['suggestion'] as String?,
        createdAt:
            DateTime.tryParse(j['created_at'] as String? ?? '')?.toLocal() ??
                DateTime.now(),
      );
}

/// Kesan dan saran disimpan di tabel `feedbacks` lewat Edge Function `auth`
/// (aksi feedback_list, feedback_save, feedback_delete).
class FeedbackRepository {
  FeedbackRepository(this._auth);

  final AuthRepository _auth;

  Future<Map<String, dynamic>> _call(
      String action, Map<String, dynamic> body) async {
    final r = await _auth.authed(action, body);
    if (!r.ok || r.data == null) throw FeedbackException(r.message);
    return r.data!;
  }

  Future<List<FeedbackEntry>> list() async {
    final d = await _call('feedback_list', const {});
    return [
      for (final e in (d['items'] as List?) ?? const [])
        FeedbackEntry.fromJson(Map<String, dynamic>.from(e as Map)),
    ];
  }

  Future<FeedbackEntry> save({
    required String impression,
    required String suggestion,
  }) async {
    final d = await _call('feedback_save', {
      'impression': impression,
      'suggestion': suggestion,
    });
    return FeedbackEntry.fromJson(Map<String, dynamic>.from(d['item'] as Map));
  }

  Future<void> delete(int id) async {
    await _call('feedback_delete', {'id': id});
  }
}
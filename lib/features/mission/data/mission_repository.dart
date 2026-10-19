import '../../auth/auth_repository.dart';
import '../models/mission_models.dart';

/// Semua data misi lewat Edge Function `auth` (butuh sesi login). Penilaian
/// dilakukan di server; aplikasi hanya mengirim jawaban.
class MissionRepository {
  MissionRepository(this._auth);

  final AuthRepository _auth;

  Future<Map<String, dynamic>> _call(
      String action, Map<String, dynamic> body) async {
    final r = await _auth.authed(action, body);
    if (!r.ok || r.data == null) throw MissionException(r.message);
    return r.data!;
  }

  Future<List<MissionInfo>> missions(String countryCode) async {
    final d = await _call('country_missions', {'country_code': countryCode});
    return [
      for (final m in d['missions'] as List)
        MissionInfo.fromJson(Map<String, dynamic>.from(m as Map)),
    ];
  }

  Future<List<QuizQuestion>> questions(int missionId) async {
    final d = await _call('mission_content', {'mission_id': missionId});
    return [
      for (final q in d['questions'] as List)
        QuizQuestion.fromJson(Map<String, dynamic>.from(q as Map)),
    ];
  }

  Future<List<CultureCard>> cards(int missionId) async {
    final d = await _call('mission_content', {'mission_id': missionId});
    return [
      for (final c in d['cards'] as List)
        CultureCard.fromJson(Map<String, dynamic>.from(c as Map)),
    ];
  }

  /// Membeli petunjuk satu soal trivia. Server memotong koin secara atomik;
  /// bila petunjuk soal ini sudah dibeli pada percobaan yang sama, tanpa biaya.
  Future<HintResult> hint(int questionId) async {
    final d = await _call('trivia_hint', {'question_id': questionId});
    final result = HintResult.fromJson(d);
    await _auth.updateCoins(result.coins);
    return result;
  }

  /// [payload]: `{'answers': [...]}` (trivia), `{'studied': [id,...]}`
  /// (kuliner & budaya), atau `{'score': n}` (mini game).
  Future<MissionResult> submit(int missionId, Map<String, dynamic> payload) async {
    final d = await _call('submit_mission', {'mission_id': missionId, ...payload});
    final result = MissionResult.fromJson(d);
    await _auth.updateCoins(result.coins);
    return result;
  }
}
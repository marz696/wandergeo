import '../../auth/auth_repository.dart';
import '../models/passport_models.dart';

class PassportException implements Exception {
  const PassportException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Paspor dibaca lewat Edge Function `auth` (aksi `passport`). Server menghitung
/// ulang seluruh hash rantai, jadi hasil "valid" tidak bisa dipalsukan dari aplikasi.
class PassportRepository {
  PassportRepository(this._auth);

  final AuthRepository _auth;

  Future<PassportData> load() async {
    final r = await _auth.authed('passport', const {});
    if (!r.ok || r.data == null) throw PassportException(r.message);
    return PassportData.fromJson(r.data!);
  }
}

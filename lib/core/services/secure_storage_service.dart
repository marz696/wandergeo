import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Menyimpan token sesi dan data pengguna di Keychain (iOS) / Keystore (Android).
class SecureStorageService {
  static const _tokenKey = 'session_token';
  static const _userKey = 'session_user';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> saveSession(String token, String userJson) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _userKey, value: userJson);
  }

  Future<String?> readToken() => _storage.read(key: _tokenKey);

  Future<String?> readUser() => _storage.read(key: _userKey);

  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
  }
}

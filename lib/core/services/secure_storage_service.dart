import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Menyimpan token sesi di Keychain (iOS) / Keystore (Android).
class SecureStorageService {
  static const _tokenKey = 'session_token';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  Future<String?> readToken() => _storage.read(key: _tokenKey);

  Future<void> clear() => _storage.delete(key: _tokenKey);
}

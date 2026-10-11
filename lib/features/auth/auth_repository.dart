import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';
import '../../core/services/secure_storage_service.dart';

class AuthResult {
  const AuthResult.success(this.token)
      : ok = true,
        message = null;
  const AuthResult.failure(this.message)
      : ok = false,
        token = null;

  final bool ok;
  final String? token;
  final String? message;
}

/// Akses data autentikasi. Halaman TIDAK boleh memanggil Supabase langsung.
///
/// Alur sebenarnya: aplikasi mengirim identifier + password ke Edge Function
/// `login`. Edge Function memverifikasi hash bcrypt di tabel `users`, lalu
/// mengembalikan token sesi. Token disimpan di Secure Storage.
class AuthRepository {
  AuthRepository({SecureStorageService? storage})
      : _storage = storage ?? SecureStorageService();

  final SecureStorageService _storage;

  Future<AuthResult> login({
    required String identifier,
    required String password,
    required bool remember,
  }) async {
    try {
      final String token;
      if (AppConfig.useMock) {
        await Future<void>.delayed(const Duration(milliseconds: 1400));
        if (password.length < 6) {
          return const AuthResult.failure('Password minimal 6 karakter');
        }
        token = 'mock-session-token';
      } else {
        final res = await Supabase.instance.client.functions.invoke(
          'login',
          body: {'identifier': identifier, 'password': password},
        );
        final data = res.data;
        if (res.status != 200 || data is! Map || data['token'] == null) {
          return const AuthResult.failure('Username atau password salah');
        }
        token = data['token'] as String;
      }

      if (remember) {
        await _storage.saveToken(token);
      } else {
        await _storage.clear();
      }
      return AuthResult.success(token);
    } catch (_) {
      return const AuthResult.failure(
        'Tidak dapat terhubung ke server. Coba lagi.',
      );
    }
  }

  Future<bool> hasSavedSession() async => (await _storage.readToken()) != null;
}

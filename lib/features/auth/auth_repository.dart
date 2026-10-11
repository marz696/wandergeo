import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../../core/services/secure_storage_service.dart';

class AuthUser {
  const AuthUser({
    required this.id,
    required this.username,
    required this.email,
    required this.title,
    this.fullName,
    this.avatarUrl,
  });

  final String id;
  final String username;
  final String email;
  final String title;
  final String? fullName;
  final String? avatarUrl;

  String get displayName =>
      (fullName != null && fullName!.trim().isNotEmpty) ? fullName! : username;

  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
        id: j['id'] as String,
        username: j['username'] as String,
        email: j['email'] as String,
        title: (j['title'] as String?) ?? 'Petualang Pemula',
        fullName: j['full_name'] as String?,
        avatarUrl: j['avatar_url'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'email': email,
        'title': title,
        'full_name': fullName,
        'avatar_url': avatarUrl,
      };
}

class AuthSession {
  const AuthSession(this.token, this.user);

  final String token;
  final AuthUser user;
}

class AuthResult {
  const AuthResult.success(this.session)
      : ok = true,
        message = null;
  const AuthResult.failure(this.message)
      : ok = false,
        session = null;

  final bool ok;
  final AuthSession? session;
  final String? message;
}

class _Resp {
  const _Resp(this.status, this.data);

  final int status; // 0 = gagal terhubung
  final Map<String, dynamic>? data;

  bool get networkError => status == 0;
}

/// Akses data autentikasi. Halaman TIDAK boleh memanggil server langsung.
///
/// Aplikasi mengirim kredensial ke Edge Function `auth` (HTTPS). Server
/// memverifikasi hash bcrypt di tabel `users` lalu mengembalikan token sesi
/// yang disimpan di Secure Storage bila "Ingat saya" aktif.
class AuthRepository {
  AuthRepository({SecureStorageService? storage})
      : _storage = storage ?? SecureStorageService();

  final SecureStorageService _storage;
  AuthSession? _session;

  AuthSession? get session => _session;
  AuthUser? get currentUser => _session?.user;

  Future<AuthResult> login({
    required String identifier,
    required String password,
    required bool remember,
  }) async {
    if (AppConfig.useMock) {
      await Future<void>.delayed(const Duration(milliseconds: 1400));
      if (password.length < 6) {
        return const AuthResult.failure('Password minimal 6 karakter');
      }
      return _finish(_mockSession(identifier), remember);
    }
    final r = await _call('login', {
      'identifier': identifier,
      'password': password,
    });
    return _handle(r, remember);
  }

  Future<AuthResult> register({
    required String fullName,
    required String username,
    required String email,
    required String password,
  }) async {
    if (AppConfig.useMock) {
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      return _finish(_mockSession(email, username: username, fullName: fullName), true);
    }
    final r = await _call('register', {
      'full_name': fullName,
      'username': username,
      'email': email,
      'password': password,
    });
    return _handle(r, true);
  }

  /// Dipakai login biometrik: true bila ada sesi tersimpan yang masih berlaku.
  /// Bila server tidak terjangkau, sesi tersimpan tetap dipercaya (mode offline).
  Future<bool> restoreSession() async {
    final token = await _storage.readToken();
    if (token == null) return false;

    AuthUser? cached;
    try {
      final raw = await _storage.readUser();
      if (raw != null) {
        cached = AuthUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      }
    } catch (_) {}

    if (AppConfig.useMock) {
      if (cached != null) _session = AuthSession(token, cached);
      return true;
    }

    final r = await _call('me', {'token': token});
    if (r.networkError) {
      if (cached == null) return false;
      _session = AuthSession(token, cached);
      return true;
    }
    final u = r.data?['user'];
    if (r.status == 200 && u is Map) {
      final user = AuthUser.fromJson(Map<String, dynamic>.from(u));
      _session = AuthSession(token, user);
      await _storage.saveSession(token, jsonEncode(user.toJson()));
      return true;
    }
    await _storage.clear();
    _session = null;
    return false;
  }

  Future<void> logout() async {
    final token = _session?.token ?? await _storage.readToken();
    _session = null;
    await _storage.clear();
    if (token != null && !AppConfig.useMock) {
      await _call('logout', {'token': token}); // upaya terbaik, tidak melempar
    }
  }

  // ---------- internal ----------

  AuthSession _mockSession(String identifier,
      {String? username, String? fullName}) {
    final name = username ??
        (identifier.contains('@') ? identifier.split('@').first : identifier);
    return AuthSession(
      'mock-session-token',
      AuthUser(
        id: 'mock',
        username: name,
        email: identifier.contains('@') ? identifier : '$name@mock.local',
        title: 'Petualang Pemula',
        fullName: fullName,
      ),
    );
  }

  Future<AuthResult> _handle(_Resp r, bool remember) async {
    if (r.networkError) {
      return const AuthResult.failure(
        'Tidak dapat terhubung ke server. Periksa internet lalu coba lagi.',
      );
    }
    final d = r.data;
    final user = d?['user'];
    final token = d?['token'];
    if ((r.status == 200 || r.status == 201) && token is String && user is Map) {
      return _finish(
        AuthSession(token, AuthUser.fromJson(Map<String, dynamic>.from(user))),
        remember,
      );
    }
    return AuthResult.failure(
      (d?['error'] as String?) ?? 'Terjadi kesalahan (kode ${r.status}).',
    );
  }

  Future<AuthResult> _finish(AuthSession s, bool remember) async {
    _session = s;
    if (remember) {
      await _storage.saveSession(s.token, jsonEncode(s.user.toJson()));
    } else {
      await _storage.clear();
    }
    return AuthResult.success(s);
  }

  Future<_Resp> _call(String action, Map<String, dynamic> body) async {
    try {
      final key = AppConfig.supabaseAnonKey;
      final res = await http
          .post(
            Uri.parse('${AppConfig.supabaseUrl}/functions/v1/auth'),
            headers: {
              'Content-Type': 'application/json',
              'apikey': key,
              // Kunci anon lama berbentuk JWT; kunci publishable baru bukan.
              if (key.startsWith('eyJ')) 'Authorization': 'Bearer $key',
            },
            body: jsonEncode({'action': action, ...body}),
          )
          .timeout(const Duration(seconds: 20));
      Map<String, dynamic>? data;
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) data = decoded;
      } catch (_) {}
      return _Resp(res.statusCode, data);
    } catch (_) {
      return const _Resp(0, null);
    }
  }
}

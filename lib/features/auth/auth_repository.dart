import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

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
    this.coins = 0,
  });

  final String id;
  final String username;
  final String email;
  final String title;
  final String? fullName;
  final String? avatarUrl;
  final int coins;

  String get displayName =>
      (fullName != null && fullName!.trim().isNotEmpty) ? fullName! : username;

  AuthUser copyWith({String? fullName, int? coins}) => AuthUser(
        id: id,
        username: username,
        email: email,
        title: title,
        fullName: fullName ?? this.fullName,
        avatarUrl: avatarUrl,
        coins: coins ?? this.coins,
      );

  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
        id: j['id'] as String,
        username: j['username'] as String,
        email: j['email'] as String,
        title: (j['title'] as String?) ?? 'Petualang Pemula',
        fullName: j['full_name'] as String?,
        avatarUrl: j['avatar_url'] as String?,
        coins: (j['coins'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'email': email,
        'title': title,
        'full_name': fullName,
        'avatar_url': avatarUrl,
        'coins': coins,
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

/// Hasil permintaan kode reset / penggantian password.
class ResetResult {
  const ResetResult.success([this.message]) : ok = true;
  const ResetResult.failure(this.message) : ok = false;

  final bool ok;
  final String? message;
}

/// Ringkasan progres paspor milik satu pengguna (dari tabel `user_progress`).
class ProfileStats {
  const ProfileStats({
    required this.selesai,
    required this.terbuka,
    required this.terkunci,
    required this.total,
    required this.totalScore,
  });

  final int selesai;
  final int terbuka;
  final int terkunci;
  final int total;
  final int totalScore;

  factory ProfileStats.fromJson(Map<String, dynamic> j) => ProfileStats(
        selesai: (j['selesai'] as num?)?.toInt() ?? 0,
        terbuka: (j['terbuka'] as num?)?.toInt() ?? 0,
        terkunci: (j['terkunci'] as num?)?.toInt() ?? 0,
        total: (j['total'] as num?)?.toInt() ?? 0,
        totalScore: (j['total_score'] as num?)?.toInt() ?? 0,
      );

  /// Hanya dipakai di mode mock (tanpa server).
  static const sample = ProfileStats(
    selesai: 1,
    terbuka: 2,
    terkunci: 9,
    total: 12,
    totalScore: 80,
  );
}

class ProfileResult {
  const ProfileResult.success(this.user, [this.stats])
      : ok = true,
        message = null;
  const ProfileResult.failure(this.message)
      : ok = false,
        user = null,
        stats = null;

  final bool ok;
  final AuthUser? user;
  final ProfileStats? stats;
  final String? message;
}

/// Hasil pemanggilan Edge Function untuk fitur lain (misi, dll).
class ApiResponse {
  const ApiResponse(this.status, this.data, {this.timedOut = false});

  final int status; // 0 = gagal terhubung
  final Map<String, dynamic>? data;

  /// true bila server tidak menjawab dalam batas waktu. Tetap dihitung sebagai
  /// [networkError] (status 0), tetapi pesannya berbeda: server mungkin masih
  /// memproses permintaan itu.
  final bool timedOut;

  bool get ok => status >= 200 && status < 300;
  bool get networkError => status == 0;

  String get message =>
      (data?['error'] as String?) ??
      (timedOut
          ? 'Server terlalu lama merespons. Coba lagi sebentar lagi.'
          : networkError
          ? 'Tidak dapat terhubung ke server. Periksa internet lalu coba lagi.'
          : 'Terjadi kesalahan (kode $status).');
}

class _Resp {
  const _Resp(this.status, this.data, {this.timedOut = false});

  final int status; // 0 = gagal terhubung
  final Map<String, dynamic>? data;
  final bool timedOut;

  bool get networkError => status == 0;
}

/// Akses data autentikasi. Halaman TIDAK boleh memanggil server langsung.
///
/// Aplikasi mengirim kredensial ke Edge Function `auth` (HTTPS). Server
/// memverifikasi hash bcrypt di tabel `users` lalu mengembalikan token sesi
/// yang disimpan di Secure Storage bila "Ingat saya" aktif.
class AuthRepository {
  static const _notConfigured =
      'Aplikasi belum terhubung ke server. Periksa URL dan kunci Supabase '
      'di app_config.dart.';

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
    if (!AppConfig.isConfigured) return const AuthResult.failure(_notConfigured);
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
    if (!AppConfig.isConfigured) return const AuthResult.failure(_notConfigured);
    final r = await _call('register', {
      'full_name': fullName,
      'username': username,
      'email': email,
      'password': password,
    });
    return _handle(r, true);
  }

  /// Meminta kode verifikasi reset password ke email akun. Server selalu
  /// menjawab sukses (tidak membocorkan apakah akun terdaftar), jadi pesan
  /// di layar bersifat umum.
  Future<ResetResult> requestPasswordReset(String identifier) async {
    if (AppConfig.useMock) {
      await Future<void>.delayed(const Duration(milliseconds: 900));
      return const ResetResult.success('Mode mock: gunakan kode 123456.');
    }
    if (!AppConfig.isConfigured) return const ResetResult.failure(_notConfigured);
    final r = await _call('forgot_request', {'identifier': identifier});
    if (r.status == 200) {
      return ResetResult.success(r.data?['message'] as String?);
    }
    return ResetResult.failure(_resetError(r));
  }

  /// Menukar kode verifikasi dengan password baru. Setelah berhasil, semua
  /// sesi lama dicabut di server; pengguna harus masuk lagi.
  Future<ResetResult> resetPassword({
    required String identifier,
    required String code,
    required String newPassword,
  }) async {
    if (AppConfig.useMock) {
      await Future<void>.delayed(const Duration(milliseconds: 900));
      return code == '123456'
          ? const ResetResult.success('Password berhasil diubah (mode mock).')
          : const ResetResult.failure('Kode salah. Di mode mock gunakan 123456.');
    }
    if (!AppConfig.isConfigured) return const ResetResult.failure(_notConfigured);
    final r = await _call('forgot_reset', {
      'identifier': identifier,
      'code': code,
      'new_password': newPassword,
    });
    if (r.status == 200) {
      return ResetResult.success(r.data?['message'] as String?);
    }
    return ResetResult.failure(_resetError(r));
  }

  String _resetError(_Resp r) => r.networkError
      ? 'Tidak dapat terhubung ke server. Periksa internet lalu coba lagi.'
      : (r.data?['error'] as String?) ?? 'Terjadi kesalahan (kode ${r.status}).';

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
    if (!AppConfig.isConfigured) return false;

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

  /// Keluar dari sesi yang sedang berjalan.
  ///
  /// Bila "Ingat saya" aktif (token tersimpan di Secure Storage), token itu
  /// SENGAJA dibiarkan: login sidik jari memakainya untuk membuka sesi lagi
  /// setelah logout, dan sidik jari tetap menjadi gerbangnya. Token juga tidak
  /// dicabut di server, jadi masih berlaku sampai kedaluwarsa (30 hari).
  /// Dengan [forgetDevice] = true, token dihapus dan dicabut di server (sidik
  /// jari tidak bisa dipakai lagi sampai login dengan password).
  Future<void> logout({bool forgetDevice = false}) async {
    final stored = await _storage.readToken();
    final token = _session?.token ?? stored;
    _session = null;
    if (stored != null && !forgetDevice) return;
    await _storage.clear();
    if (token != null && !AppConfig.useMock) {
      await _call('logout', {'token': token}); // upaya terbaik, tidak melempar
    }
  }

  /// Data akun + statistik progres terbaru dari server (aksi `profile`).
  Future<ProfileResult> fetchProfile() => _profileCall('profile', const {});

  /// Mengubah nama tampilan di tabel `users` (aksi `update_profile`).
  Future<ProfileResult> updateFullName(String fullName) =>
      _profileCall('update_profile', {'full_name': fullName});

  /// Mengunggah foto profil ke Supabase Storage (aksi `upload_avatar`). Server
  /// menyimpan link publiknya di `users.avatar_url`; user terbaru dikembalikan.
  Future<ProfileResult> uploadAvatar(Uint8List bytes) {
    if (AppConfig.useMock) return Future.value(_avatarNeedsServer);
    return _profileCall('upload_avatar', {'image_base64': base64Encode(bytes)});
  }

  /// Menghapus foto profil (aksi `remove_avatar`): file di Storage dan link-nya.
  Future<ProfileResult> removeAvatar() {
    if (AppConfig.useMock) return Future.value(_avatarNeedsServer);
    return _profileCall('remove_avatar', const {});
  }

  static const _avatarNeedsServer =
      ProfileResult.failure('Foto profil membutuhkan koneksi ke server.');

  /// Progres tiap negara milik pengguna (aksi `progress`). Tabel
  /// `user_progress` terkunci dari Data API, jadi dibaca lewat Edge Function.
  /// Null bila gagal, offline, atau mode mock.
  Future<List<Map<String, dynamic>>?> fetchProgress() async {
    final s = _session;
    if (s == null || AppConfig.useMock || !AppConfig.isConfigured) return null;
    final r = await _call('progress', {'token': s.token});
    final list = r.data?['progress'];
    if (r.status == 200 && list is List) {
      return [
        for (final e in list)
          if (e is Map) Map<String, dynamic>.from(e),
      ];
    }
    return null;
  }

  /// Memanggil aksi Edge Function dengan token sesi yang sedang aktif.
  ///
  /// [timeout] membatasi lama menunggu jawaban; fitur yang memanggil layanan
  /// lambat (Pemandu AI) memberi batas lebih panjang dari bawaan 20 detik.
  Future<ApiResponse> authed(
    String action,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final sess = _session;
    if (sess == null) {
      return const ApiResponse(401, {'error': 'Sesi berakhir. Silakan masuk lagi.'});
    }
    if (AppConfig.useMock || !AppConfig.isConfigured) {
      return const ApiResponse(
          0, {'error': 'Fitur ini membutuhkan koneksi ke server.'});
    }
    final r = await _call(action, {...body, 'token': sess.token}, timeout: timeout);
    return ApiResponse(r.status, r.data, timedOut: r.timedOut);
  }

  /// Memperbarui jumlah koin setelah misi selesai (memori + penyimpanan aman).
  Future<void> updateCoins(int coins) async {
    final sess = _session;
    if (sess == null) return;
    final user = sess.user.copyWith(coins: coins);
    _session = AuthSession(sess.token, user);
    if (await _storage.readToken() != null) {
      await _storage.saveSession(sess.token, jsonEncode(user.toJson()));
    }
  }

  // ---------- internal ----------

  Future<ProfileResult> _profileCall(
    String action,
    Map<String, dynamic> extra,
  ) async {
    final s = _session;
    if (s == null) {
      return const ProfileResult.failure(
        'Sesi tidak ditemukan. Silakan login ulang.',
      );
    }

    if (AppConfig.useMock) {
      if (action == 'update_profile') {
        final user = s.user.copyWith(fullName: extra['full_name'] as String?);
        await _saveUser(user);
        return ProfileResult.success(user);
      }
      return ProfileResult.success(s.user, ProfileStats.sample);
    }
    if (!AppConfig.isConfigured) {
      return const ProfileResult.failure(_notConfigured);
    }

    final r = await _call(action, {'token': s.token, ...extra});
    if (r.networkError) {
      return const ProfileResult.failure(
        'Tidak dapat terhubung ke server. Periksa internet lalu coba lagi.',
      );
    }

    final d = r.data;
    final u = d?['user'];
    if (r.status == 200 && u is Map) {
      final user = AuthUser.fromJson(Map<String, dynamic>.from(u));
      await _saveUser(user);
      final st = d?['stats'];
      return ProfileResult.success(
        user,
        st is Map ? ProfileStats.fromJson(Map<String, dynamic>.from(st)) : null,
      );
    }
    if (r.status == 401) {
      return const ProfileResult.failure(
        'Sesi berakhir. Silakan keluar lalu login ulang.',
      );
    }
    final error = d?['error'] as String?;
    if (r.status == 400 && error == 'Aksi tidak dikenal') {
      return const ProfileResult.failure(
        'Server belum mendukung fitur ini. Perbarui fungsi auth di Supabase.',
      );
    }
    return ProfileResult.failure(
      error ?? 'Terjadi kesalahan (kode ${r.status}).',
    );
  }

  /// Memperbarui data user di sesi berjalan, dan di Secure Storage bila sesi
  /// memang disimpan ("Ingat saya").
  Future<void> _saveUser(AuthUser user) async {
    final s = _session;
    if (s == null) return;
    _session = AuthSession(s.token, user);
    if (await _storage.readToken() != null) {
      await _storage.saveSession(s.token, jsonEncode(user.toJson()));
    }
  }

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

  Future<_Resp> _call(
    String action,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
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
          .timeout(timeout);
      Map<String, dynamic>? data;
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) data = decoded;
      } catch (_) {}
      return _Resp(res.statusCode, data);
    } on TimeoutException {
      return const _Resp(0, null, timedOut: true);
    } catch (_) {
      return const _Resp(0, null);
    }
  }
}
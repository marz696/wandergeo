import 'package:flutter/foundation.dart';

import '../../core/config/app_config.dart';
import '../../core/services/biometric_service.dart';
import 'auth_repository.dart';

enum BiometricKind { fingerprint, face }

enum BiometricResult { success, notAvailable, noSession, failed, cancelled }

class LoginController extends ChangeNotifier {
  LoginController(this._repo, {BiometricService? biometric})
      : _bio = biometric ?? BiometricService();

  final AuthRepository _repo;
  final BiometricService _bio;

  bool isLoading = false;
  bool isBiometricBusy = false;
  bool showPassword = false;
  bool remember = true;
  BiometricKind biometricKind = BiometricKind.fingerprint;
  String? errorMessage;
  bool _cancelled = false;

  void togglePassword() {
    showPassword = !showPassword;
    notifyListeners();
  }

  void setRemember(bool value) {
    remember = value;
    notifyListeners();
  }

  Future<bool> login(String identifier, String password) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    final result = await _repo.login(
      identifier: identifier,
      password: password,
      remember: remember,
    );

    isLoading = false;
    errorMessage = result.ok ? null : result.message;
    notifyListeners();
    return result.ok;
  }

  /// Login biometrik membuka kembali sesi yang tersimpan di Secure Storage,
  /// jadi pengguna harus pernah login dengan password + "Ingat saya".
  Future<BiometricResult> loginWithBiometric(BiometricKind kind) async {
    biometricKind = kind;
    isBiometricBusy = true;
    _cancelled = false;
    notifyListeners();
    try {
      final available = await _bio.isAvailable();
      if (_cancelled) return BiometricResult.cancelled;
      if (!available) {
        if (AppConfig.useMock) {
          // Emulator tanpa biometrik: simulasikan agar alur UI tetap bisa dicoba.
          await Future<void>.delayed(const Duration(milliseconds: 1800));
          return _cancelled ? BiometricResult.cancelled : BiometricResult.success;
        }
        return BiometricResult.notAvailable;
      }
      final ok = await _bio.authenticate();
      if (_cancelled) return BiometricResult.cancelled;
      if (!ok) return BiometricResult.failed;
      if (!AppConfig.useMock && !await _repo.restoreSession()) {
        return BiometricResult.noSession;
      }
      return BiometricResult.success;
    } finally {
      isBiometricBusy = false;
      notifyListeners();
    }
  }

  Future<void> cancelBiometric() async {
    _cancelled = true;
    isBiometricBusy = false;
    notifyListeners();
    await _bio.cancel();
  }
}

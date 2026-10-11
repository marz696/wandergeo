import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/primary_button.dart';
import '../../routes.dart';
import 'login_controller.dart';
import 'widgets/hero_illustration.dart';
import 'widgets/login_overlays.dart';

/// Halaman login: ilustrasi di atas, sheet putih naik dari bawah, isi form
/// muncul bergantian. Login password + biometrik (sidik jari / wajah).
/// Layar verifikasi biometrik dan "Berhasil masuk" tampil sebagai overlay
/// di dalam sheet (sama dengan mockup).
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  /// Tinggi minimum sheet agar seluruh isi (sampai "Daftar") terlihat tanpa scroll.
  static const double _sheetMinHeight = 540;

  final _form = GlobalKey<FormState>();
  final _idCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  bool _done = false;

  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  )..forward();

  late final Animation<Offset> _sheetSlide = Tween<Offset>(
    begin: const Offset(0, 1),
    end: Offset.zero,
  ).animate(CurvedAnimation(
    parent: _enter,
    curve: const Interval(.1, .5, curve: Curves.easeOutCubic),
  ));

  /// Animasi bertahap untuk 9 elemen di dalam sheet.
  late final List<Animation<double>> _stag = List.generate(9, (i) {
    final start = .33 + i * .055;
    return CurvedAnimation(
      parent: _enter,
      curve: Interval(start, math.min(1.0, start + .3), curve: Curves.easeOut),
    );
  });

  @override
  void dispose() {
    _enter.dispose();
    _idCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  Widget _in(int i, Widget child) => FadeTransition(
        opacity: _stag[i],
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, .3), end: Offset.zero)
              .animate(_stag[i]),
          child: child,
        ),
      );

  void _snack(String message, {bool error = true}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? AppColors.error : AppColors.ink,
      ));
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final ctrl = context.read<LoginController>();
    final ok = await ctrl.login(_idCtrl.text.trim(), _pwCtrl.text);
    if (!mounted) return;
    if (ok) {
      setState(() => _done = true);
    } else {
      _snack(ctrl.errorMessage ?? 'Login gagal');
    }
  }

  Future<void> _biometric(BiometricKind kind) async {
    FocusScope.of(context).unfocus();
    final result = await context.read<LoginController>().loginWithBiometric(kind);
    if (!mounted) return;
    switch (result) {
      case BiometricResult.success:
        setState(() => _done = true);
      case BiometricResult.notAvailable:
        _snack('Biometrik tidak tersedia di perangkat ini');
      case BiometricResult.noSession:
        _snack('Masuk dengan password dulu (aktifkan "Ingat saya")');
      case BiometricResult.failed:
        _snack('Verifikasi biometrik gagal');
      case BiometricResult.cancelled:
        break;
    }
  }

  void _goHome() => Navigator.of(context)
      .pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<LoginController>();
    final size = MediaQuery.sizeOf(context);
    final scale = size.width / 390;
    // Posisi sheet di mockup = 350 (dari tinggi 844). Pada layar yang lebih pendek
    // sheet dinaikkan dan ilustrasi ikut bergeser ke atas supaya tetap serasi.
    final sheetTop = math.max(200.0, math.min(350 * scale, size.height - _sheetMinHeight));
    final heroTop = sheetTop - 350 * scale;

    return Scaffold(
      backgroundColor: AppColors.sky,
      body: Stack(
        children: [
          Positioned(
            top: heroTop,
            left: 0,
            right: 0,
            child: HeroIllustration(enter: _enter),
          ),
          Positioned(
            top: sheetTop,
            left: 0,
            right: 0,
            bottom: 0,
            child: SlideTransition(position: _sheetSlide, child: _sheet(ctrl)),
          ),
        ],
      ),
    );
  }

  Widget _sheet(LoginController ctrl) {
    const radius = BorderRadius.vertical(top: Radius.circular(32));
    final busy = ctrl.isLoading || ctrl.isBiometricBusy;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: radius,
        boxShadow: [
          BoxShadow(color: Color(0x290E2238), blurRadius: 28, offset: Offset(0, -8)),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            Positioned.fill(
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
                  child: Form(key: _form, child: _formColumn(ctrl, busy)),
                ),
              ),
            ),
            Positioned.fill(
              child: BiometricOverlay(
                visible: ctrl.isBiometricBusy,
                kind: ctrl.biometricKind,
                onCancel: ctrl.cancelBiometric,
              ),
            ),
            Positioned.fill(
              child: SuccessOverlay(visible: _done, onContinue: _goHome),
            ),
          ],
        ),
      ),
    );
  }

  Widget _formColumn(LoginController ctrl, bool busy) {
    return Column(
      children: [
        _in(
          0,
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _in(
          1,
          Text.rich(
            TextSpan(children: [
              TextSpan(text: 'Masuk untuk Mulai\n', style: AppTheme.heading(24)),
              TextSpan(
                text: 'Petualanganmu',
                style: AppTheme.heading(24, color: AppColors.teal),
              ),
            ]),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 16),
        _in(
          2,
          AppTextField(
            controller: _idCtrl,
            hint: 'Masukkan email atau username',
            icon: Icons.mail_outline,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username],
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Email atau username wajib diisi'
                : null,
          ),
        ),
        const SizedBox(height: 14),
        _in(
          3,
          AppTextField(
            controller: _pwCtrl,
            hint: 'Masukkan password',
            icon: Icons.lock_outline,
            obscure: !ctrl.showPassword,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            autofillHints: const [AutofillHints.password],
            suffix: IconButton(
              tooltip: ctrl.showPassword ? 'Sembunyikan password' : 'Tampilkan password',
              onPressed: ctrl.togglePassword,
              icon: Icon(
                ctrl.showPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppColors.hint,
              ),
            ),
            validator: (v) =>
                (v == null || v.length < 6) ? 'Password minimal 6 karakter' : null,
          ),
        ),
        const SizedBox(height: 8),
        _in(
          4,
          Row(
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: Checkbox(
                  value: ctrl.remember,
                  activeColor: AppColors.ink,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  onChanged: (v) => ctrl.setRemember(v ?? false),
                ),
              ),
              const SizedBox(width: 6),
              const Text('Ingat saya', style: TextStyle(fontSize: 13)),
              const Spacer(),
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => _snack('Fitur lupa password menyusul', error: false),
                child: const Text(
                  'Lupa password?',
                  style: TextStyle(
                    color: AppColors.teal,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        _in(
          5,
          PrimaryButton(label: 'Masuk', loading: ctrl.isLoading, onPressed: _submit),
        ),
        const SizedBox(height: 16),
        _in(
          6,
          Row(
            children: const [
              Expanded(child: Divider(color: AppColors.border)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'Atau masuk dengan',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ),
              Expanded(child: Divider(color: AppColors.border)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _in(
          7,
          Row(
            children: [
              Expanded(
                child: _BioButton(
                  icon: Icons.fingerprint,
                  label: 'Sidik jari',
                  onPressed: busy ? null : () => _biometric(BiometricKind.fingerprint),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _BioButton(
                  icon: Icons.face_outlined,
                  label: 'Wajah',
                  onPressed: busy ? null : () => _biometric(BiometricKind.face),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _in(
          8,
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Belum punya akun? ',
                style: TextStyle(fontSize: 14, color: AppColors.muted),
              ),
              InkWell(
                onTap: () => _snack('Halaman daftar menyusul', error: false),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'Daftar',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.teal,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BioButton extends StatelessWidget {
  const _BioButton({required this.icon, required this.label, required this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: AppColors.teal, size: 20),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        minimumSize: const Size(0, 50),
        side: const BorderSide(color: AppColors.border, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

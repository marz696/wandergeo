import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/primary_button.dart';
import '../../routes.dart';
import 'login_controller.dart';
import 'register_page.dart';
import 'widgets/hero_illustration.dart';
import 'widgets/login_overlays.dart';

/// Halaman login: ilustrasi di atas, sheet putih naik dari bawah, isi form
/// muncul bergantian. Login password + sidik jari.
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

  /// true di layar pendek / saat keyboard terbuka: jarak antar elemen dirapatkan.
  bool _compact = false;

  double _g(double v) => _compact ? v * .72 : v;

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
      _goHome();
    } else {
      _snack(ctrl.errorMessage ?? 'Login gagal');
    }
  }

  Future<void> _biometric() async {
    FocusScope.of(context).unfocus();
    final result = await context.read<LoginController>().loginWithBiometric();
    if (!mounted) return;
    switch (result) {
      case BiometricResult.success:
        _goHome();
      case BiometricResult.notAvailable:
        _snack('Sidik jari tidak tersedia di perangkat ini');
      case BiometricResult.noSession:
        _snack('Belum ada sesi tersimpan. Masuk dengan password dulu dan centang "Ingat saya"');
      case BiometricResult.failed:
        _snack('Verifikasi sidik jari gagal');
      case BiometricResult.cancelled:
        break;
    }
  }

  void _goHome() => Navigator.of(context)
      .pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<LoginController>();
    final mq = MediaQuery.of(context);
    final keyboard = mq.viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: AppColors.sky,
      body: LayoutBuilder(
        builder: (context, box) {
          // Semua ukuran diturunkan dari area yang benar-benar tersedia
          // (sudah memperhitungkan keyboard), bukan angka tetap.
          final w = box.maxWidth;
          final h = box.maxHeight;
          _compact = h < 720 || keyboard;
          final need = (_compact ? 440.0 : _sheetMinHeight) +
              (keyboard ? 0 : mq.padding.bottom);
          final minTop = keyboard ? 120.0 : 200.0;
          final maxTop = 350 * w / 390; // posisi sheet di mockup
          final sheetTop = (h - need).clamp(minTop, maxTop).toDouble();
          // Ilustrasi selalu mulai dari atas layar dan diskalakan agar muat di
          // atas sheet, jadi pesawat/matahari tidak pernah terpotong.
          final heroScale = sheetTop / 350;

          return Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(end: heroScale),
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOut,
                  builder: (_, v, __) => HeroIllustration(
                    enter: _enter,
                    scale: v,
                    topInset: mq.padding.top,
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOut,
                top: sheetTop,
                left: 0,
                right: 0,
                bottom: 0,
                child: SlideTransition(
                  position: _sheetSlide,
                  child: _sheet(ctrl),
                ),
              ),
            ],
          );
        },
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
                onCancel: ctrl.cancelBiometric,
              ),
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
        SizedBox(height: _g(14)),
        _in(
          1,
          Text.rich(
            TextSpan(children: [
              TextSpan(text: 'Masuk untuk Mulai\n', style: AppTheme.heading(_compact ? 21 : 24)),
              TextSpan(
                text: 'Petualanganmu',
                style: AppTheme.heading(_compact ? 21 : 24, color: AppColors.teal),
              ),
            ]),
            textAlign: TextAlign.center,
          ),
        ),
        SizedBox(height: _g(16)),
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
        SizedBox(height: _g(14)),
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
        SizedBox(height: _g(8)),
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
            ],
          ),
        ),
        SizedBox(height: _g(6)),
        _in(
          5,
          PrimaryButton(label: 'Masuk', loading: ctrl.isLoading, onPressed: _submit),
        ),
        SizedBox(height: _g(16)),
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
        SizedBox(height: _g(14)),
        _in(
          7,
          SizedBox(
            width: double.infinity,
            child: _BioButton(
              icon: Icons.fingerprint,
              label: 'Sidik jari',
              onPressed: busy ? null : _biometric,
            ),
          ),
        ),
        SizedBox(height: _g(12)),
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
                onTap: busy ? null : () => Navigator.of(context).push(RegisterPage.route()),
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

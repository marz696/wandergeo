import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/round_icon_button.dart';
import 'auth_repository.dart';

/// Langkah 2 lupa password: kode 6 digit dari email + password baru.
/// Setelah berhasil, semua sesi lama dicabut dan pengguna kembali ke halaman
/// masuk untuk login dengan password baru.
class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({
    super.key,
    required this.identifier,
    this.autoStartCooldown = true,
  });

  final String identifier;

  /// true bila kode baru saja diminta (tombol kirim ulang menunggu jeda).
  final bool autoStartCooldown;

  static Route<void> route({
    required String identifier,
    bool autoStartCooldown = true,
  }) =>
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 380),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (_, __, ___) => ResetPasswordPage(
          identifier: identifier,
          autoStartCooldown: autoStartCooldown,
        ),
        transitionsBuilder: (_, anim, __, child) {
          final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, .06), end: Offset.zero)
                  .animate(curved),
              child: child,
            ),
          );
        },
      );

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  // Sama dengan RESET_COOLDOWN_SEC di Edge Function.
  static const _cooldownSeconds = 60;

  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _showPw = false;
  bool _loading = false;
  bool _resending = false;
  int _left = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.autoStartCooldown) _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _left = _cooldownSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _left--);
      if (_left <= 0) t.cancel();
    });
  }

  void _snack(String msg, {bool error = true}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? AppColors.error : AppColors.ink,
      ));
  }

  Future<void> _resend() async {
    if (_left > 0 || _resending) return;
    setState(() => _resending = true);
    final r = await context
        .read<AuthRepository>()
        .requestPasswordReset(widget.identifier);
    if (!mounted) return;
    setState(() => _resending = false);
    if (r.ok) {
      _startCooldown();
      _snack(r.message ?? 'Kode baru telah dikirim.', error: false);
    } else {
      _snack(r.message ?? 'Gagal mengirim ulang kode');
    }
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    final r = await context.read<AuthRepository>().resetPassword(
          identifier: widget.identifier,
          code: _code.text.trim(),
          newPassword: _password.text,
        );
    if (!mounted) return;
    setState(() => _loading = false);
    if (!r.ok) {
      _snack(r.message ?? 'Gagal mengubah password');
      return;
    }
    // Snackbar milik ScaffoldMessenger aplikasi, jadi tetap tampil di halaman masuk.
    _snack(r.message ?? 'Password berhasil diubah.', error: false);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RoundIconButton(
                    icon: Icons.arrow_back_rounded,
                    label: 'Kembali',
                    elevated: false,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(height: 20),
                  Text('Buat Password Baru', style: AppTheme.heading(28)),
                  const SizedBox(height: 4),
                  const Text(
                    'Masukkan kode 6 digit dari email, lalu pilih password baru.',
                    style: TextStyle(color: AppColors.muted, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.sea,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 18, color: AppColors.teal),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Kode berlaku 15 menit. Bila tidak ada di kotak masuk, '
                            'periksa folder spam.',
                            style: TextStyle(
                                fontSize: 12.5,
                                height: 1.35,
                                color: AppColors.deepNavy),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  AppTextField(
                    controller: _code,
                    hint: 'Kode 6 digit',
                    icon: Icons.pin_outlined,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    validator: (v) => RegExp(r'^\d{6}$').hasMatch((v ?? '').trim())
                        ? null
                        : 'Masukkan 6 digit kode dari email',
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    controller: _password,
                    hint: 'Password baru',
                    icon: Icons.lock_outline_rounded,
                    obscure: !_showPw,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newPassword],
                    suffix: IconButton(
                      tooltip:
                          _showPw ? 'Sembunyikan password' : 'Tampilkan password',
                      onPressed: () => setState(() => _showPw = !_showPw),
                      icon: Icon(
                        _showPw
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppColors.hint,
                      ),
                    ),
                    validator: (v) {
                      final p = v ?? '';
                      if (p.length < 8) return 'Password minimal 8 karakter';
                      if (!RegExp(r'[A-Za-z]').hasMatch(p) ||
                          !RegExp(r'\d').hasMatch(p)) {
                        return 'Harus mengandung huruf dan angka';
                      }
                      return null;
                    },
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(4, 6, 4, 0),
                    child: Text(
                      'Minimal 8 karakter, mengandung huruf dan angka.',
                      style: TextStyle(fontSize: 12, color: AppColors.hint),
                    ),
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    controller: _confirm,
                    hint: 'Ulangi password baru',
                    icon: Icons.lock_reset_rounded,
                    obscure: !_showPw,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    validator: (v) =>
                        v == _password.text ? null : 'Password tidak sama',
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: 'Ubah Password',
                    loading: _loading,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: TextButton(
                      onPressed: (_left > 0 || _resending) ? null : _resend,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.teal,
                        textStyle: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      child: Text(
                        _resending
                            ? 'Mengirim…'
                            : _left > 0
                                ? 'Kirim ulang kode dalam $_left dtk'
                                : 'Kirim ulang kode',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/round_icon_button.dart';
import 'auth_repository.dart';
import 'reset_password_page.dart';

/// Langkah 1 lupa password: pengguna mengisi email atau username, server
/// mengirim kode verifikasi 6 digit ke email akun tersebut.
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key, this.initialIdentifier = ''});

  /// Diisi dari kolom login agar pengguna tidak mengetik ulang.
  final String initialIdentifier;

  static Route<void> route({String initialIdentifier = ''}) =>
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 380),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (_, __, ___) =>
            ForgotPasswordPage(initialIdentifier: initialIdentifier),
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
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _form = GlobalKey<FormState>();
  late final _id = TextEditingController(text: widget.initialIdentifier);
  bool _loading = false;

  @override
  void dispose() {
    _id.dispose();
    super.dispose();
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

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final identifier = _id.text.trim().toLowerCase();
    setState(() => _loading = true);
    final r = await context.read<AuthRepository>().requestPasswordReset(identifier);
    if (!mounted) return;
    setState(() => _loading = false);
    if (!r.ok) {
      _snack(r.message ?? 'Gagal meminta kode');
      return;
    }
    _snack(r.message ?? 'Kode verifikasi telah dikirim.', error: false);
    Navigator.of(context).push(ResetPasswordPage.route(identifier: identifier));
  }

  /// Sudah punya kode (misalnya baru saja meminta): lewati pengiriman.
  void _haveCode() {
    if (!_form.currentState!.validate()) return;
    Navigator.of(context).push(
      ResetPasswordPage.route(
        identifier: _id.text.trim().toLowerCase(),
        autoStartCooldown: false,
      ),
    );
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
                  Text('Lupa Password?', style: AppTheme.heading(28)),
                  const SizedBox(height: 4),
                  const Text(
                    'Masukkan email atau username akunmu. Kami akan mengirim kode '
                    'verifikasi 6 digit ke email akun tersebut.',
                    style: TextStyle(color: AppColors.muted, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  AppTextField(
                    controller: _id,
                    hint: 'Email atau username',
                    icon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    autofillHints: const [AutofillHints.username],
                    validator: (v) => (v ?? '').trim().isEmpty
                        ? 'Email atau username wajib diisi'
                        : null,
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: 'Kirim Kode',
                    loading: _loading,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: InkWell(
                      onTap: _loading ? null : _haveCode,
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text.rich(
                          TextSpan(
                            text: 'Sudah punya kode? ',
                            style: TextStyle(color: AppColors.muted),
                            children: [
                              TextSpan(
                                text: 'Masukkan kode',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.teal,
                                ),
                              ),
                            ],
                          ),
                        ),
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

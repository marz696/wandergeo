import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/round_icon_button.dart';
import '../../routes.dart';
import 'auth_repository.dart';

/// Pendaftaran akun. Server (Edge Function `auth`) yang melakukan hash bcrypt;
/// bila berhasil, pengguna langsung masuk (sesi dibuat otomatis).
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  static Route<void> route() => PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 380),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (_, __, ___) => const RegisterPage(),
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
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _showPw = false;
  bool _loading = false;

  static final _usernameRe = RegExp(r'^[a-z0-9_]{3,20}$');
  static final _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.error,
      ));
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final repo = context.read<AuthRepository>();
    setState(() => _loading = true);
    final result = await repo.register(
      fullName: _name.text.trim(),
      username: _username.text.trim().toLowerCase(),
      email: _email.text.trim().toLowerCase(),
      password: _password.text,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (result.ok) {
      _goHome();
    } else {
      _snack(result.message ?? 'Pendaftaran gagal');
    }
  }

  void _goHome() => Navigator.of(context)
      .pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          SafeArea(
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
                      Text('Buat Akun', style: AppTheme.heading(28)),
                      const SizedBox(height: 4),
                      const Text(
                        'Mulai petualangan geografimu bersama WanderGeo.',
                        style: TextStyle(color: AppColors.muted, height: 1.4),
                      ),
                      const SizedBox(height: 24),
                      AppTextField(
                        controller: _name,
                        hint: 'Nama lengkap',
                        icon: Icons.person_outline_rounded,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.name],
                        validator: (v) => (v ?? '').trim().length < 2
                            ? 'Nama minimal 2 karakter'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      AppTextField(
                        controller: _username,
                        hint: 'Username (huruf kecil, angka, _)',
                        icon: Icons.alternate_email_rounded,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.newUsername],
                        validator: (v) => _usernameRe
                                .hasMatch((v ?? '').trim().toLowerCase())
                            ? null
                            : 'Username 3-20 karakter: huruf kecil, angka, atau _',
                      ),
                      const SizedBox(height: 14),
                      AppTextField(
                        controller: _email,
                        hint: 'Email',
                        icon: Icons.mail_outline_rounded,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        validator: (v) => _emailRe.hasMatch((v ?? '').trim())
                            ? null
                            : 'Format email tidak valid',
                      ),
                      const SizedBox(height: 14),
                      AppTextField(
                        controller: _password,
                        hint: 'Password',
                        icon: Icons.lock_outline_rounded,
                        obscure: !_showPw,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.newPassword],
                        suffix: IconButton(
                          tooltip: _showPw
                              ? 'Sembunyikan password'
                              : 'Tampilkan password',
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
                        hint: 'Ulangi password',
                        icon: Icons.lock_reset_rounded,
                        obscure: !_showPw,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                        validator: (v) =>
                            v == _password.text ? null : 'Password tidak sama',
                      ),
                      const SizedBox(height: 24),
                      PrimaryButton(
                        label: 'Daftar',
                        loading: _loading,
                        onPressed: _submit,
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: InkWell(
                          onTap: () => Navigator.of(context).maybePop(),
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Text.rich(
                              TextSpan(
                                text: 'Sudah punya akun? ',
                                style: TextStyle(color: AppColors.muted),
                                children: [
                                  TextSpan(
                                    text: 'Masuk',
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
        ],
      ),
    );
  }
}

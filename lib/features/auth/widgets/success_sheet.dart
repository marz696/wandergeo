import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/animated_check.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../routes.dart';

/// Layar "Berhasil masuk" dengan centang beranimasi.
class SuccessSheet extends StatelessWidget {
  const SuccessSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (_) => const SuccessSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 36, 32, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AnimatedCheck(),
            const SizedBox(height: 18),
            Text('Berhasil masuk', style: AppTheme.heading(22)),
            const SizedBox(height: 8),
            const Text(
              'Selamat datang kembali, Agen. Paspormu sudah aktif.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.muted),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Mulai menjelajah',
              onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
                AppRoutes.home,
                (_) => false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

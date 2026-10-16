import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../explore/models/country.dart';
import 'notification_planner.dart';
import 'notification_prefs.dart';
import 'notification_service.dart';

/// Ajakan sekali saja untuk mengaktifkan pengingat harian (soft prompt), supaya
/// izin sistem tidak diminta tiba-tiba tanpa konteks.
class NotificationPrompt {
  NotificationPrompt._();

  static Future<void> maybeShow(BuildContext context, List<Country> countries) async {
    final prefs = await NotificationPrefs.load();
    if (prefs.asked || !context.mounted) return;
    await prefs.copyWith(asked: true).save(); // tampil sekali saja

    if (!context.mounted) return;
    final enable = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(color: AppColors.sea, shape: BoxShape.circle),
                child: const Icon(Icons.notifications_active_outlined,
                    color: AppColors.teal, size: 26),
              ),
              const SizedBox(height: 14),
              Text('Aktifkan pengingat harian?', style: AppTheme.heading(20)),
              const SizedBox(height: 6),
              const Text(
                'WanderGeo mengirim satu pengingat misi setiap hari pukul 19.00, dan kabar saat kamu menyelesaikan negara. Waktunya bisa diubah di Profil > Notifikasi.',
                style: TextStyle(color: AppColors.muted, height: 1.45),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.ink,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  child: const Text('Aktifkan'),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Nanti saja'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (enable != true) return;
    final granted = await NotificationService.instance.requestPermission();
    if (!granted) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Izin notifikasi ditolak. Kamu bisa mengaktifkannya di pengaturan HP.'),
          behavior: SnackBarBehavior.floating,
        ));
      }
      return;
    }
    await (await NotificationPrefs.load()).copyWith(reminder: true).save();
    await NotificationPlanner.refresh(countries);
  }
}

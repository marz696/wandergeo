import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/round_icon_button.dart';
import '../auth/auth_repository.dart';
import 'notification_planner.dart';
import 'notification_prefs.dart';
import 'notification_service.dart';

/// Pengaturan notifikasi: pengingat harian, jam pengingat, notifikasi pencapaian,
/// dan tombol uji.
class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  static Route<void> route() => MaterialPageRoute<void>(
        builder: (_) => const NotificationSettingsPage(),
      );

  @override
  State<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  NotificationPrefs? _p;

  String get _userId => context.read<AuthRepository>().currentUser?.id ?? 'guest';

  @override
  void initState() {
    super.initState();
    NotificationPrefs.load().then((p) {
      if (mounted) setState(() => _p = p);
    });
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));
  }

  Future<void> _save(NotificationPrefs p) async {
    setState(() => _p = p);
    await p.save();
  }

  Future<void> _toggleReminder(bool on) async {
    final p = _p!;
    if (on) {
      final ok = await NotificationService.instance.requestPermission();
      if (!ok) {
        _snack('Izin notifikasi ditolak. Aktifkan lewat pengaturan HP.');
        return;
      }
      await _save(p.copyWith(reminder: true, asked: true));
      await NotificationPlanner.refreshFromLocal(_userId);
      _snack('Pengingat aktif setiap ${p.time.format(context)}.');
    } else {
      await _save(p.copyWith(reminder: false));
      await NotificationService.instance.cancelReminders();
    }
  }

  Future<void> _pickTime() async {
    final p = _p!;
    final t = await showTimePicker(
      context: context,
      initialTime: p.time,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (t == null) return;
    await _save(p.copyWith(hour: t.hour, minute: t.minute));
    if (p.reminder) await NotificationPlanner.refreshFromLocal(_userId);
  }

  Future<void> _test() async {
    final ok = await NotificationService.instance.requestPermission();
    if (!ok) {
      _snack('Izin notifikasi belum diberikan.');
      return;
    }
    await NotificationService.instance.showEvent(
      title: 'Notifikasi uji WanderGeo',
      body: 'Kalau pesan ini muncul, notifikasi di HP-mu sudah berfungsi.',
      force: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: p == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  Row(
                    children: [
                      RoundIconButton(
                        icon: Icons.arrow_back_rounded,
                        label: 'Kembali',
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Notifikasi', style: AppTheme.heading(22)),
                            const Text('Pengingat dan kabar pencapaian',
                                style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _card([
                    _switch(
                      icon: Icons.alarm_rounded,
                      title: 'Pengingat misi harian',
                      subtitle: 'Satu notifikasi setiap hari, isinya mengikuti progresmu',
                      value: p.reminder,
                      onChanged: _toggleReminder,
                    ),
                    const Divider(height: 1, indent: 70),
                    ListTile(
                      enabled: p.reminder,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      leading: _icon(Icons.schedule_rounded),
                      title: const Text('Jam pengingat', style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('Setiap ${p.time.format(context)}'),
                      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.hint),
                      onTap: p.reminder ? _pickTime : null,
                    ),
                  ]),
                  const SizedBox(height: 14),
                  _card([
                    _switch(
                      icon: Icons.emoji_events_outlined,
                      title: 'Pencapaian',
                      subtitle: 'Saat sebuah negara selesai dan negara baru terbuka',
                      value: p.events,
                      onChanged: (v) => _save(p.copyWith(events: v)),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  _card([
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      leading: _icon(Icons.notifications_active_outlined),
                      title: const Text('Kirim notifikasi uji', style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: const Text('Pastikan notifikasi muncul di HP-mu'),
                      onTap: _test,
                    ),
                  ]),
                  const SizedBox(height: 18),
                  const Text(
                    'Catatan: beberapa HP (misalnya Xiaomi, Oppo, Vivo, Huawei) menghentikan aplikasi di latar belakang sehingga pengingat terlambat atau tidak muncul. Bila itu terjadi, izinkan WanderGeo berjalan di latar belakang atau matikan penghemat baterai untuk aplikasi ini. Pengingat bisa tertunda beberapa menit karena sistem menghemat daya.',
                    style: TextStyle(fontSize: 12.5, color: AppColors.muted, height: 1.5),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _card(List<Widget> children) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      );

  Widget _icon(IconData i) => Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(color: AppColors.sea, shape: BoxShape.circle),
        child: Icon(i, size: 21, color: AppColors.teal),
      );

  Widget _switch({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) =>
      SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        secondary: _icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12.5)),
        value: value,
        activeColor: AppColors.teal,
        onChanged: onChanged,
      );
}

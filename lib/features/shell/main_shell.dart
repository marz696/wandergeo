import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../routes.dart';
import '../auth/auth_repository.dart';
import '../explore/explore_page.dart';
import '../passport/passport_page.dart';
import '../profile/profile_page.dart';
import 'floating_nav_bar.dart';
import 'tab_placeholder_page.dart';
import '../feedback/feedback_page.dart';

/// Kerangka utama setelah login: 5 tab (Eksplorasi, Paspor Digital, Profil,
/// Kesan & Saran, Logout). Logout tidak berpindah halaman, hanya dialog.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  static const _logoutIndex = 4;

  static const _items = [
    NavItemData(
      icon: Icons.explore_rounded,
      label: 'Eksplorasi',
      shortLabel: 'Eksplorasi',
    ),
    NavItemData(
      icon: Icons.badge_rounded,
      label: 'Paspor Digital',
      shortLabel: 'Paspor',
    ),
    NavItemData(
      icon: Icons.person_rounded,
      label: 'Profil',
      shortLabel: 'Profil',
    ),
    NavItemData(
      icon: Icons.chat_bubble_rounded,
      label: 'Kesan dan Saran',
      shortLabel: 'Kesan',
    ),
    NavItemData(
      icon: Icons.logout_rounded,
      label: 'Logout',
      shortLabel: 'Logout',
      tint: Color(0xFFFFB4AB),
    ),
  ];

  // Dinaikkan tiap tab Paspor dibuka, supaya stempel baru langsung muncul.
  final _passportTick = ValueNotifier<int>(0);

  late final List<Widget> _pages = <Widget>[
    const ExplorePage(),
    PassportPage(refresh: _passportTick),
    const ProfilePage(),
    const FeedbackPage(),
  ];

  @override
  void dispose() {
    _passportTick.dispose();
    super.dispose();
  }

  int _index = 0;

  void _onTap(int i) {
    if (i == _logoutIndex) {
      _confirmLogout();
      return;
    }
    if (i == _index) return;
    if (i == 1) _passportTick.value++;
    HapticFeedback.selectionClick();
    setState(() => _index = i);
  }

  Future<void> _confirmLogout() async {
    HapticFeedback.mediumImpact();
    final repo = context.read<AuthRepository>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Keluar dari WanderGeo?', style: AppTheme.heading(18)),
        content: const Text(
          'Sesi login di perangkat ini akan dihapus. Kamu perlu masuk lagi '
          'untuk melanjutkan petualangan.',
          style: TextStyle(color: AppColors.muted, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await repo.logout();
    if (!mounted) return;
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _index == 0,
      onPopInvoked: (didPop) {
        if (!didPop) setState(() => _index = 0);
      },
      child: Scaffold(
        body: Stack(
          children: [
            // Semua tab tetap hidup (peta tidak dimuat ulang); yang aktif
            // muncul dengan fade, yang lain berhenti beranimasi.
            for (var i = 0; i < _pages.length; i++)
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: i != _index,
                  child: ExcludeSemantics(
                    excluding: i != _index,
                    // AnimatedOpacity harus DI LUAR TickerMode: kalau tidak,
                    // animasi fade-out tab yang ditinggalkan ikut terhenti dan
                    // tab itu menutupi tab yang baru dibuka.
                    child: AnimatedOpacity(
                      opacity: i == _index ? 1 : 0,
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOut,
                      child: TickerMode(
                        enabled: i == _index,
                        child: _pages[i],
                      ),
                    ),
                  ),
                ),
              ),
            // Pudar di belakang nav agar daftar tidak terpotong kasar.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 130,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.background.withOpacity(0),
                        AppColors.background,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: FloatingNavBar(
                items: _items,
                currentIndex: _index,
                onTap: _onTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
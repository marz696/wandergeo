import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../auth/auth_repository.dart';
import '../explore/models/country.dart';
import 'culture_page.dart';
import 'data/mission_repository.dart';
import 'minigame_page.dart';
import 'models/mission_models.dart';
import 'trivia_page.dart';
import 'widgets/mission_ui.dart';

/// Daftar misi sebuah negara. Trivia dan Kuliner & Budaya wajib untuk
/// menyelesaikan negara; mini game opsional (bonus koin).
class MissionHubPage extends StatefulWidget {
  const MissionHubPage({super.key, required this.country});

  final Country country;

  static Route<void> route(Country country) => PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 380),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (_, __, ___) => MissionHubPage(country: country),
        transitionsBuilder: (_, anim, __, child) {
          final c = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: c,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, .06), end: Offset.zero).animate(c),
              child: child,
            ),
          );
        },
      );

  @override
  State<MissionHubPage> createState() => _MissionHubPageState();
}

class _MissionHubPageState extends State<MissionHubPage>
    with SingleTickerProviderStateMixin {
  late final MissionRepository _repo =
      MissionRepository(context.read<AuthRepository>());

  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();

  List<MissionInfo>? _missions;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final m = await _repo.missions(widget.country.code);
      if (!mounted) return;
      setState(() {
        _missions = m;
        _error = null;
      });
    } on MissionException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  Future<void> _open(MissionInfo m) async {
    HapticFeedback.selectionClick();
    final Widget page = switch (m.type) {
      'trivia' => TriviaPage(country: widget.country, mission: m),
      'kuliner_budaya' => CulturePage(country: widget.country, mission: m),
      _ => MiniGamePage(country: widget.country, mission: m),
    };
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
    if (mounted) _load(); // status & skor terbaru
  }

  late final List<Animation<double>> _slots = List.generate(8, (i) {
    final start = math.min(.7, i * .12);
    return CurvedAnimation(
      parent: _enter,
      curve: Interval(start, math.min(1.0, start + .4), curve: Curves.easeOutCubic),
    );
  });

  Animation<double> _slot(int i) => _slots[math.min(i, _slots.length - 1)];

  Widget _reveal(int i, Widget child) {
    final a = _slot(i);
    return FadeTransition(
      opacity: a,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, .12), end: Offset.zero).animate(a),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.country;
    final auth = context.watch<AuthRepository>();
    final ms = _missions;
    final doneCount = ms?.where((m) => m.completed).length ?? 0;
    final requiredDone =
        ms != null && ms.where((m) => m.isRequired).every((m) => m.completed);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            _reveal(
              0,
              MissionTopBar(
                title: c.name,
                subtitle: 'Misi negara',
                onBack: () => Navigator.of(context).maybePop(),
                trailing: CoinChip(coins: auth.currentUser?.coins ?? 0),
              ),
            ),
            const SizedBox(height: 16),
            _reveal(1, _hero(c, doneCount, requiredDone)),
            const SizedBox(height: 20),
            _reveal(2, Text('Pilih misi', style: AppTheme.heading(17))),
            const SizedBox(height: 10),
            if (_error != null)
              _reveal(3, _errorCard())
            else if (ms == null)
              const _MissionSkeleton()
            else
              for (var i = 0; i < ms.length; i++)
                _reveal(3 + i, _MissionCard(mission: ms[i], onTap: () => _open(ms[i]))),
            if (requiredDone) ...[
              const SizedBox(height: 6),
              _reveal(6, _completeBanner(c)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _hero(Country c, int done, bool requiredDone) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          colors: [AppColors.deepNavy, AppColors.teal],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.18),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(c.code,
                style: AppTheme.heading(22, color: Colors.white)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.capital, style: AppTheme.heading(20, color: Colors.white)),
                const SizedBox(height: 2),
                Text('${c.language} · ${c.currency}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Colors.white.withOpacity(.85), fontSize: 12.5)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    for (var i = 0; i < 3; i++)
                      Icon(Icons.star_rounded,
                          size: 16,
                          color: i < c.difficulty
                              ? AppColors.gold
                              : Colors.white.withOpacity(.3)),
                  ],
                ),
              ],
            ),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: done / 3),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => ProgressRing(
              value: v,
              child: Text('$done/3',
                  style: AppTheme.heading(15, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _completeBanner(Country c) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F6EF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.success.withOpacity(.4)),
      ),
      child: Row(
        children: [
          StampBadge(code: c.code, name: c.name, size: 72),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Negara selesai!',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: Color(0xFF1F7A52))),
                SizedBox(height: 2),
                Text('Trivia dan Kuliner & Budaya sudah lulus. Mini game tetap bisa dimainkan untuk bonus.',
                    style: TextStyle(fontSize: 12.5, color: AppColors.muted, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 36, color: AppColors.hint),
          const SizedBox(height: 8),
          Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: _load, child: const Text('Coba lagi')),
        ],
      ),
    );
  }
}

class _MissionCard extends StatelessWidget {
  const _MissionCard({required this.mission, required this.onTap});

  final MissionInfo mission;
  final VoidCallback onTap;

  ({IconData icon, List<Color> colors, String subtitle}) get _v => switch (mission.type) {
        'trivia' => (
            icon: Icons.quiz_rounded,
            colors: const [AppColors.teal, AppColors.deepNavy],
            subtitle: '20 soal · ±7 menit',
          ),
        'kuliner_budaya' => (
            icon: Icons.restaurant_menu_rounded,
            colors: const [AppColors.gold, Color(0xFFC98F12)],
            subtitle: '4 kartu belajar',
          ),
        _ => (
            icon: Icons.sports_esports_rounded,
            colors: const [Color(0xFF6C5CE7), Color(0xFF4834B8)],
            subtitle: 'Tangkap koin · 20 detik',
          ),
      };

  @override
  Widget build(BuildContext context) {
    final v = _v;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        elevation: 3,
        shadowColor: AppColors.ink.withOpacity(.15),
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(17),
                    gradient: LinearGradient(
                      colors: v.colors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Icon(v.icon, color: Colors.white),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(mission.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTheme.heading(16)),
                          ),
                          const SizedBox(width: 6),
                          _Tag(required: mission.isRequired),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(v.subtitle,
                          style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (mission.completed)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Icon(Icons.check_circle_rounded, color: AppColors.success),
                      Text('Skor ${mission.bestScore}',
                          style: const TextStyle(fontSize: 11.5, color: AppColors.success, fontWeight: FontWeight.w700)),
                    ],
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('+${mission.rewardCoins} koin',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: AppColors.goldDark)),
                      const Text('Mulai',
                          style: TextStyle(fontSize: 11.5, color: AppColors.teal, fontWeight: FontWeight.w700)),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.required});

  final bool required;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: required ? const Color(0xFFFBEFD0) : AppColors.sea,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(required ? 'WAJIB' : 'OPSIONAL',
          style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: required ? AppColors.goldDark : AppColors.deepNavy)),
    );
  }
}

class _MissionSkeleton extends StatelessWidget {
  const _MissionSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 3; i++)
          Container(
            height: 82,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.border),
            ),
          ),
      ],
    );
  }
}

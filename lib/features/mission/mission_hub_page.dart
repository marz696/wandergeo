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

  Widget _reveal(int i, Widget child) {
    final a = _slots[math.min(i, _slots.length - 1)];
    return FadeTransition(
      opacity: a,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, .1), end: Offset.zero).animate(a),
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
            _reveal(1, _Hero(country: c, done: doneCount)),
            const SizedBox(height: 26),
            _reveal(
              2,
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Misi', style: AppTheme.heading(18)),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 2),
                      child: Text(
                        'Selesaikan dua misi wajib untuk mendapat stempel',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_error != null)
              _reveal(3, _errorCard())
            else if (ms == null)
              const _MissionSkeleton()
            else
              for (var i = 0; i < ms.length; i++)
                _reveal(3 + i, _MissionCard(mission: ms[i], onTap: () => _open(ms[i]))),
            if (requiredDone) ...[
              const SizedBox(height: 4),
              _reveal(6, _CompleteBanner(country: c)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _errorCard() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            const Icon(Icons.cloud_off_outlined, size: 34, color: AppColors.hint),
            const SizedBox(height: 8),
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted, height: 1.4)),
            const SizedBox(height: 10),
            OutlinedButton(onPressed: _load, child: const Text('Coba lagi')),
          ],
        ),
      );
}

/// Kartu negara: latar navy polos dengan garis tipis, tanpa gradien.
class _Hero extends StatelessWidget {
  const _Hero({required this.country, required this.done});

  final Country country;
  final int done;

  @override
  Widget build(BuildContext context) {
    final c = country;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        color: AppColors.ink,
        child: CustomPaint(
          painter: _RingsPainter(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white.withOpacity(.35)),
                        ),
                        child: Text(c.code,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              letterSpacing: 1.4,
                            )),
                      ),
                      const SizedBox(height: 12),
                      Text(c.capital, style: AppTheme.heading(24, color: Colors.white)),
                      const SizedBox(height: 4),
                      Text('${c.language} · ${c.currency}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white.withOpacity(.7), fontSize: 12.5)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          for (var i = 0; i < 3; i++)
                            Container(
                              width: 7,
                              height: 7,
                              margin: const EdgeInsets.only(right: 5),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i < c.difficulty
                                    ? AppColors.gold
                                    : Colors.white.withOpacity(.25),
                              ),
                            ),
                          const SizedBox(width: 3),
                          Text('Tingkat ${c.difficulty}',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(.7), fontSize: 11.5)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: done / 3),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, __) => ProgressRing(
                    value: v,
                    size: 66,
                    stroke: 5,
                    track: Colors.white.withOpacity(.18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$done/3', style: AppTheme.heading(15, color: Colors.white)),
                        Text('misi',
                            style: TextStyle(color: Colors.white.withOpacity(.6), fontSize: 10)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Lingkaran konsentris tipis sebagai tekstur latar (bukan warna).
class _RingsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withOpacity(.06);
    final c = Offset(size.width * .92, -size.height * .1);
    for (var r = 40.0; r < size.width; r += 34) {
      canvas.drawCircle(c, r, p);
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) => false;
}

class _MissionCard extends StatelessWidget {
  const _MissionCard({required this.mission, required this.onTap});

  final MissionInfo mission;
  final VoidCallback onTap;

  ({IconData icon, String subtitle}) get _v => switch (mission.type) {
        'trivia' => (icon: Icons.quiz_outlined, subtitle: '20 soal · ±7 menit'),
        'kuliner_budaya' =>
          (icon: Icons.restaurant_menu_outlined, subtitle: '4 kartu belajar'),
        _ => (icon: Icons.sports_esports_outlined, subtitle: 'Tangkap koin · 20 detik'),
      };

  @override
  Widget build(BuildContext context) {
    final v = _v;
    final done = mission.completed;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: done ? AppColors.success.withOpacity(.35) : AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
            child: Row(
              children: [
                // Satu gaya ikon untuk semua misi: lembut, satu warna aksen.
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: done ? const Color(0xFFE8F6EF) : AppColors.sea,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    done ? Icons.check_rounded : v.icon,
                    size: 24,
                    color: done ? AppColors.success : AppColors.teal,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(mission.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.heading(15.5)),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            mission.isRequired ? 'Wajib' : 'Opsional',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: mission.isRequired ? AppColors.teal : AppColors.hint,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6),
                            child: Text('·', style: TextStyle(color: AppColors.hint)),
                          ),
                          Flexible(
                            child: Text(v.subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                if (done)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Selesai',
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.success)),
                      const SizedBox(height: 2),
                      Text('Skor ${mission.bestScore}',
                          style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
                    ],
                  )
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.monetization_on_outlined,
                          size: 16, color: AppColors.goldDark),
                      const SizedBox(width: 3),
                      Text('+${mission.rewardCoins}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppColors.goldDark)),
                      const SizedBox(width: 2),
                      const Icon(Icons.chevron_right_rounded, color: AppColors.hint),
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

class _CompleteBanner extends StatelessWidget {
  const _CompleteBanner({required this.country});

  final Country country;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.success.withOpacity(.35)),
      ),
      child: Row(
        children: [
          StampBadge(code: country.code, name: country.name, size: 70),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Negara selesai',
                    style: TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.success)),
                SizedBox(height: 3),
                Text(
                  'Dua misi wajib sudah lulus dan stempel masuk ke paspormu. Mini game tetap bisa dimainkan untuk bonus koin.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.muted, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
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
            height: 80,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
          ),
      ],
    );
  }
}

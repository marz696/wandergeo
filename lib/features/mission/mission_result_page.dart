import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../explore/data/country_seed.dart';
import '../explore/models/country.dart';
import '../notifications/notification_planner.dart';
import 'models/mission_models.dart';
import 'widgets/mission_ui.dart';

/// Hasil sebuah misi: cincin skor, bintang, koin, stempel paspor bila negara
/// baru selesai, dan negara yang baru terbuka.
class MissionResultPage extends StatefulWidget {
  const MissionResultPage({
    super.key,
    required this.country,
    required this.mission,
    required this.result,
    this.bestStreak,
    this.onRetry,
  });

  final Country country;
  final MissionInfo mission;
  final MissionResult result;
  final int? bestStreak;
  final VoidCallback? onRetry;

  static Route<void> route({
    required Country country,
    required MissionInfo mission,
    required MissionResult result,
    int? bestStreak,
    VoidCallback? onRetry,
  }) =>
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, __, ___) => MissionResultPage(
          country: country,
          mission: mission,
          result: result,
          bestStreak: bestStreak,
          onRetry: onRetry,
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      );

  @override
  State<MissionResultPage> createState() => _MissionResultPageState();
}

class _MissionResultPageState extends State<MissionResultPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  )..forward();

  late final Animation<double> _ring =
      CurvedAnimation(parent: _c, curve: const Interval(0, .4, curve: Curves.easeOutCubic));
  late final Animation<double> _stamp =
      CurvedAnimation(parent: _c, curve: const Interval(.55, .8, curve: Curves.easeOutBack));
  late final Animation<double> _unlock =
      CurvedAnimation(parent: _c, curve: const Interval(.8, 1, curve: Curves.easeOutCubic));

  MissionResult get _r => widget.result;

  @override
  void initState() {
    super.initState();
    _r.passed ? HapticFeedback.mediumImpact() : HapticFeedback.selectionClick();
    if (_r.countryCompleted) {
      // Beri waktu animasi stempel di layar sebelum notifikasi muncul.
      Future<void>.delayed(const Duration(milliseconds: 1500), () {
        NotificationPlanner.countryCompleted(
          country: widget.country.name,
          unlocked: [for (final c in _r.unlocked) _nameOf(c)],
        );
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double get _ratio => switch (widget.mission.type) {
        'minigame' => (_r.score / 200).clamp(0, 1).toDouble(),
        _ => _r.total == 0 ? 0 : (_r.correct / _r.total).clamp(0, 1).toDouble(),
      };

  int get _stars => switch (widget.mission.type) {
        'trivia' => !_r.passed ? 0 : (_ratio >= .95 ? 3 : (_ratio >= .8 ? 2 : 1)),
        'kuliner_budaya' => _r.passed ? 3 : 0,
        _ => _r.score >= 300 ? 3 : (_r.score >= 200 ? 2 : (_r.score >= 100 ? 1 : 0)),
      };

  String get _headline {
    if (!_r.passed) {
      return switch (widget.mission.type) {
        'trivia' => 'Belum lulus',
        'minigame' => 'Waktu habis',
        _ => 'Belum lengkap',
      };
    }
    if (_r.countryCompleted) return '${widget.country.name} selesai!';
    return switch (widget.mission.type) {
      'trivia' => _ratio >= .95 ? 'Sempurna!' : 'Lulus!',
      'kuliner_budaya' => 'Misi selesai!',
      _ => 'Target tercapai!',
    };
  }

  String get _message {
    if (!_r.passed) {
      return switch (widget.mission.type) {
        'trivia' => 'Butuh minimal 60% jawaban benar. Coba lagi!',
        'minigame' => 'Butuh minimal 100 poin untuk menyelesaikan misi.',
        _ => 'Buka semua kartu untuk menyelesaikan misi.',
      };
    }
    if (_r.countryCompleted) return 'Kamu mengumpulkan stempel paspor baru.';
    if (_r.coinsEarned > 0) return 'Kamu mendapat ${_r.coinsEarned} koin.';
    return 'Misi ini sudah pernah kamu selesaikan; koin tidak bertambah lagi.';
  }

  String get _statLabel => switch (widget.mission.type) {
        'trivia' => 'Benar',
        'kuliner_budaya' => 'Kartu',
        _ => 'Poin',
      };

  String get _statValue => widget.mission.type == 'minigame'
      ? '${_r.score}'
      : '${_r.correct}/${_r.total}';

  String _nameOf(String code) => CountrySeed.all
      .firstWhere((c) => c.code == code, orElse: () => widget.country)
      .name;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      AnimatedBuilder(
                        animation: _c,
                        builder: (_, __) => ProgressRing(
                          value: _ratio * _ring.value,
                          size: 170,
                          stroke: 14,
                          color: _r.passed ? AppColors.teal : AppColors.error,
                          track: AppColors.border,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('${(_r.score * _ring.value).round()}',
                                  style: AppTheme.heading(40)),
                              const Text('poin',
                                  style: TextStyle(fontSize: 12, color: AppColors.muted)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _starsRow(),
                      const SizedBox(height: 10),
                      Text(_headline, textAlign: TextAlign.center, style: AppTheme.heading(26)),
                      const SizedBox(height: 4),
                      Text(_message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.muted, height: 1.4)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _stat(_statLabel, _statValue),
                          const SizedBox(width: 10),
                          _stat('Koin', '+${_r.coinsEarned}'),
                          const SizedBox(width: 10),
                          _stat(widget.bestStreak != null ? 'Beruntun' : 'Skor negara',
                              widget.bestStreak != null ? '${widget.bestStreak}' : '${_r.countryScore}'),
                        ],
                      ),
                      if (_r.countryCompleted) ...[
                        const SizedBox(height: 18),
                        AnimatedBuilder(
                          animation: _stamp,
                          builder: (_, child) => Opacity(
                            opacity: _stamp.value.clamp(0, 1).toDouble(),
                            child: Transform.rotate(
                              angle: -.17,
                              child: Transform.scale(
                                scale: 2.2 - 1.2 * _stamp.value,
                                child: child,
                              ),
                            ),
                          ),
                          child: StampBadge(
                              code: widget.country.code, name: widget.country.name, size: 132),
                        ),
                      ],
                      if (_r.unlocked.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        FadeTransition(
                          opacity: _unlock,
                          child: SlideTransition(
                            position: Tween<Offset>(begin: const Offset(0, .3), end: Offset.zero)
                                .animate(_unlock),
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final code in _r.unlocked)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE8F6EF),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.lock_open_rounded,
                                            size: 16, color: Color(0xFF1F7A52)),
                                        const SizedBox(width: 6),
                                        Text('${_nameOf(code)} terbuka',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF1F7A52))),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.ink,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                    textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  child: const Text('Kembali ke misi'),
                ),
              ),
              if (widget.onRetry != null && !_r.passed) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: widget.onRetry,
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                      side: const BorderSide(color: AppColors.border, width: 1.5),
                    ),
                    child: const Text('Coba lagi'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _starsRow() => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < 3; i++)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: i < _stars ? 1 : 0),
              duration: Duration(milliseconds: 500 + i * 250),
              curve: Curves.elasticOut,
              builder: (_, v, __) => Transform.scale(
                scale: .6 + .4 * v,
                child: Icon(Icons.star_rounded,
                    size: 38, color: Color.lerp(AppColors.border, AppColors.gold, v)),
              ),
            ),
        ],
      );

  Widget _stat(String label, String value) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: AppColors.ink.withOpacity(.08), blurRadius: 10)],
          ),
          child: Column(
            children: [
              Text(value, style: AppTheme.heading(18)),
              const SizedBox(height: 2),
              Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
            ],
          ),
        ),
      );
}

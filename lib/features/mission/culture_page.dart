import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../auth/auth_repository.dart';
import '../explore/models/country.dart';
import 'data/mission_repository.dart';
import 'mission_result_page.dart';
import 'models/mission_models.dart';
import 'widgets/mission_ui.dart';

/// Kuliner & Budaya: kartu belajar yang bisa dibalik. Semua kartu harus
/// dibuka agar misi selesai.
class CulturePage extends StatefulWidget {
  const CulturePage({super.key, required this.country, required this.mission});

  final Country country;
  final MissionInfo mission;

  @override
  State<CulturePage> createState() => _CulturePageState();
}

class _CulturePageState extends State<CulturePage> with TickerProviderStateMixin {
  late final MissionRepository _repo =
      MissionRepository(context.read<AuthRepository>());

  /// Detak animasi bersama (mengambang + kilau) agar hemat controller.
  late final AnimationController _ambient = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..forward();

  List<CultureCard> _cards = const [];
  final Set<int> _studied = {};
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ambient.dispose();
    _enter.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final c = await _repo.cards(widget.mission.id);
      if (!mounted) return;
      setState(() {
        _cards = c;
        _loading = false;
      });
    } on MissionException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  bool get _allDone => _cards.isNotEmpty && _studied.length == _cards.length;

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final result = await _repo.submit(widget.mission.id, {'studied': _studied.toList()});
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MissionResultPage.route(
        country: widget.country,
        mission: widget.mission,
        result: result,
      ));
    } on MissionException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.country;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                children: [
                  MissionTopBar(
                    title: 'Kuliner & Budaya',
                    subtitle: 'Ketuk kartu untuk membalik',
                    onBack: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(height: 14),
                  _banner(c),
                  const SizedBox(height: 14),
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : _error != null
                            ? _errorView()
                            : _grid(),
                  ),
                  _cta(),
                ],
              ),
            ),
            if (_submitting)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.white.withOpacity(.85),
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _banner(Country c) {
    final total = _cards.isEmpty ? 4 : _cards.length;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [AppColors.deepNavy, AppColors.teal],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.18),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Text(c.code, style: AppTheme.heading(17, color: Colors.white)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Kenali budaya ${c.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.heading(16, color: Colors.white)),
                const SizedBox(height: 2),
                Text('Buka semua kartu untuk mendapat +${widget.mission.rewardCoins} koin',
                    style: TextStyle(color: Colors.white.withOpacity(.85), fontSize: 12)),
              ],
            ),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: _studied.length / total),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => ProgressRing(
              value: v,
              size: 46,
              stroke: 5,
              child: Text('${_studied.length}/$total',
                  style: AppTheme.heading(12, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _grid() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 8),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: .66,
        children: [
          for (var i = 0; i < _cards.length; i++) _entering(i, _cards[i]),
        ],
      ),
    );
  }

  late final List<Animation<double>> _enters = List.generate(8, (i) {
    final start = math.min(.6, i * .14);
    return CurvedAnimation(
      parent: _enter,
      curve: Interval(start, math.min(1.0, start + .4), curve: Curves.easeOutBack),
    );
  });

  Widget _entering(int i, CultureCard card) {
    final a = _enters[math.min(i, _enters.length - 1)];
    return AnimatedBuilder(
      animation: a,
      builder: (_, child) => Opacity(
        opacity: a.value.clamp(0, 1).toDouble(),
        child: Transform.scale(scale: .8 + .2 * a.value, child: child),
      ),
      child: _CultureCardTile(
        card: card,
        ambient: _ambient,
        phase: i * .25,
        studied: _studied.contains(card.id),
        onFirstFlip: () => setState(() => _studied.add(card.id)),
      ),
    );
  }

  Widget _cta() {
    final done = widget.mission.completed;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 20),
      child: AnimatedBuilder(
        animation: _ambient,
        builder: (_, child) => Transform.scale(
          scale: _allDone ? 1 + .02 * math.sin(_ambient.value * 2 * math.pi * 2) : 1,
          child: child,
        ),
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: FilledButton(
            onPressed: _allDone && !_submitting ? _submit : null,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.ink,
              disabledBackgroundColor: AppColors.border,
              disabledForegroundColor: AppColors.hint,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
              textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            child: Text(_allDone
                ? (done ? 'Selesai' : 'Selesaikan misi · +${widget.mission.rewardCoins} koin')
                : 'Buka semua kartu (${_studied.length}/${_cards.isEmpty ? 4 : _cards.length})'),
          ),
        ),
      ),
    );
  }

  Widget _errorView() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 44, color: AppColors.hint),
            const SizedBox(height: 10),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Coba lagi')),
          ],
        ),
      );
}

// ---------------------------------------------------------------------------

class _CultureCardTile extends StatefulWidget {
  const _CultureCardTile({
    required this.card,
    required this.ambient,
    required this.phase,
    required this.studied,
    required this.onFirstFlip,
  });

  final CultureCard card;
  final Animation<double> ambient;
  final double phase;
  final bool studied;
  final VoidCallback onFirstFlip;

  @override
  State<_CultureCardTile> createState() => _CultureCardTileState();
}

class _CultureCardTileState extends State<_CultureCardTile> with TickerProviderStateMixin {
  late final AnimationController _flip = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void dispose() {
    _flip.dispose();
    _burst.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_flip.isAnimating) return;
    HapticFeedback.selectionClick();
    if (_flip.value < .5) {
      _flip.forward();
      if (!widget.studied) {
        _burst.forward(from: 0);
        widget.onFirstFlip();
      }
    } else {
      _flip.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = cultureVisual(widget.card.icon);
    return Semantics(
      button: true,
      label: '${widget.card.title}, ketuk untuk membalik kartu',
      child: GestureDetector(
        onTap: _toggle,
        child: AnimatedBuilder(
          animation: Listenable.merge([_flip, widget.ambient, _burst]),
          builder: (_, __) {
            final t = Curves.easeInOutCubic.transform(_flip.value);
            final angle = t * math.pi;
            final showFront = angle <= math.pi / 2;
            final lift = 1 + math.sin(math.pi * t) * .05;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: Transform.scale(
                    scale: lift,
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, .0013)
                        ..rotateY(angle),
                      child: showFront
                          ? _front(v)
                          : Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.rotationY(math.pi),
                              child: _back(v),
                            ),
                    ),
                  ),
                ),
                if (_burst.isAnimating)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(painter: _BurstPainter(_burst.value)),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _front(({IconData icon, List<Color> colors}) v) {
    final p = (widget.ambient.value + widget.phase) % 1.0;
    final bob = math.sin(p * 2 * math.pi) * 5;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          colors: v.colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(color: v.colors.last.withOpacity(.35), blurRadius: 18, offset: const Offset(0, 8)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _RingsPainter())),
            Positioned(
              right: -26,
              bottom: -22,
              child: Transform.rotate(
                angle: -.3,
                child: Icon(v.icon, size: 150, color: Colors.white.withOpacity(.12)),
              ),
            ),
            Positioned.fill(child: CustomPaint(painter: _ShinePainter(p))),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.22),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(widget.card.category,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                      ),
                      const Spacer(),
                      if (widget.studied)
                        Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          child: const Icon(Icons.check_rounded, size: 16, color: AppColors.success),
                        ),
                    ],
                  ),
                  Expanded(
                    child: Center(
                      child: Transform.translate(
                        offset: Offset(0, bob),
                        child: Container(
                          width: 78,
                          height: 78,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(.2),
                            border: Border.all(color: Colors.white.withOpacity(.55), width: 2),
                          ),
                          child: Icon(v.icon, size: 40, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                  Text(widget.card.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.heading(18, color: Colors.white)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.touch_app_rounded, size: 14, color: Colors.white.withOpacity(.8)),
                      const SizedBox(width: 4),
                      Text('Ketuk untuk membuka',
                          style: TextStyle(color: Colors.white.withOpacity(.85), fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _back(({IconData icon, List<Color> colors}) v) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: v.colors.first.withOpacity(.35), width: 2),
        boxShadow: [
          BoxShadow(color: AppColors.ink.withOpacity(.12), blurRadius: 18, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: v.colors),
                ),
                child: Icon(v.icon, size: 20, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(widget.card.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.heading(14.5)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(height: 2, width: 34, color: v.colors.first.withOpacity(.5)),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: Text(widget.card.fact,
                  style: const TextStyle(fontSize: 12.5, height: 1.45, color: AppColors.muted)),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.verified_rounded, size: 16, color: AppColors.success),
              const SizedBox(width: 4),
              const Text('Dipelajari',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.success)),
              const Spacer(),
              const Icon(Icons.flip_camera_android_rounded, size: 16, color: AppColors.hint),
            ],
          ),
        ],
      ),
    );
  }
}

/// Lingkaran konsentris halus sebagai tekstur latar kartu.
class _RingsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.white.withOpacity(.08);
    final c = Offset(size.width * .85, size.height * .12);
    for (var r = 30.0; r < size.height; r += 28) {
      canvas.drawCircle(c, r, p);
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) => false;
}

/// Pita cahaya diagonal yang menyapu kartu.
class _ShinePainter extends CustomPainter {
  _ShinePainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final x = -size.width * .6 + progress * size.width * 2.4;
    final rect = Rect.fromLTWH(x, 0, size.width * .5, size.height);
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withOpacity(0),
          Colors.white.withOpacity(.22),
          Colors.white.withOpacity(0),
        ],
      ).createShader(rect);
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(.5);
    canvas.translate(-size.width / 2, -size.height / 2);
    canvas.drawRect(rect.inflate(30), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ShinePainter old) => old.progress != progress;
}

/// Percikan bintang/titik saat kartu pertama kali dibuka.
class _BurstPainter extends CustomPainter {
  _BurstPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    const n = 16;
    for (var i = 0; i < n; i++) {
      final a = (i / n) * 2 * math.pi + (i.isEven ? .1 : -.1);
      final reach = (50 + (i % 3) * 22) * Curves.easeOutCubic.transform(t);
      final pos = c + Offset(math.cos(a), math.sin(a)) * (reach + 20);
      final paint = Paint()
        ..color = (i % 2 == 0 ? AppColors.gold : Colors.white).withOpacity((1 - t).clamp(0, 1).toDouble());
      canvas.drawCircle(pos, (i % 3 == 0 ? 4.5 : 3) * (1 - t * .5), paint);
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t;
}

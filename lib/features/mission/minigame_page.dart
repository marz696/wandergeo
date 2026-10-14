import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../auth/auth_repository.dart';
import '../explore/models/country.dart';
import 'data/mission_repository.dart';
import 'mission_result_page.dart';
import 'models/mission_models.dart';
import 'widgets/mission_ui.dart';

class _Item {
  _Item(this.x, this.y, this.v, this.coin);

  double x;
  double y;
  final double v;
  final bool coin;
}

enum _Phase { ready, playing, ending }

/// Mini game "Tangkap Koin": keranjang digerakkan dengan accelerometer
/// (sensor kedua). Bila sensor tidak ada (emulator), geser layar.
class MiniGamePage extends StatefulWidget {
  const MiniGamePage({super.key, required this.country, required this.mission});

  final Country country;
  final MissionInfo mission;

  @override
  State<MiniGamePage> createState() => _MiniGamePageState();
}

class _MiniGamePageState extends State<MiniGamePage> with SingleTickerProviderStateMixin {
  static const _seconds = 20.0;
  static const _target = 100;
  static const _basketW = 88.0;
  static const _itemSize = 34.0;

  /// Ubah tanda ini (1 <-> -1) bila arah miring terasa terbalik di HP-mu.
  static const _tiltSign = -1.0;
  static const _tiltSpeed = 120.0; // px/detik per m/s²

  late final MissionRepository _repo =
      MissionRepository(context.read<AuthRepository>());

  late final Ticker _ticker = createTicker(_tick);
  StreamSubscription<AccelerometerEvent>? _sub;
  final _rnd = math.Random();

  _Phase _phase = _Phase.ready;
  final List<_Item> _items = [];
  Duration _last = Duration.zero;
  double _w = 0;
  double _h = 0;
  double _basketX = 0;
  double _tilt = 0;
  bool _sensorOk = false;
  double _left = _seconds;
  double _spawn = 0;
  int _score = 0;
  Color? _flash;
  double _flashT = 0;

  @override
  void initState() {
    super.initState();
    try {
      _sub = accelerometerEventStream(samplingPeriod: SensorInterval.gameInterval).listen(
        (e) {
          _tilt = e.x;
          if (!_sensorOk && mounted) setState(() => _sensorOk = true);
        },
        onError: (_) {
          if (mounted) setState(() => _sensorOk = false);
        },
        cancelOnError: false,
      );
    } catch (_) {
      _sensorOk = false;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ticker.dispose();
    super.dispose();
  }

  void _start() {
    HapticFeedback.mediumImpact();
    setState(() {
      _items.clear();
      _score = 0;
      _left = _seconds;
      _spawn = 0;
      _basketX = (_w - _basketW) / 2;
      _phase = _Phase.playing;
    });
    _last = Duration.zero;
    _ticker.start();
  }

  void _tick(Duration elapsed) {
    final dt = _last == Duration.zero ? 0.016 : math.min(.05, (elapsed - _last).inMicroseconds / 1e6);
    _last = elapsed;
    if (_phase != _Phase.playing) return;

    _left -= dt;
    if (_left <= 0) {
      _end();
      return;
    }

    // Gerak keranjang dari accelerometer (zona mati kecil agar tidak bergetar).
    final dead = _tilt.abs() < .6 ? 0.0 : _tilt;
    _basketX = (_basketX + dead * _tiltSign * _tiltSpeed * dt).clamp(0, math.max(0, _w - _basketW)).toDouble();

    // Munculkan benda; makin lama makin cepat.
    _spawn -= dt;
    if (_spawn <= 0) {
      _spawn = math.max(.3, .6 - (_seconds - _left) * .012);
      _items.add(_Item(
        _rnd.nextDouble() * math.max(1, _w - _itemSize),
        -_itemSize,
        150 + _rnd.nextDouble() * 120 + (_seconds - _left) * 5,
        _rnd.nextDouble() < .78,
      ));
    }

    final basketTop = _h - 54;
    _items.removeWhere((it) {
      it.y += it.v * dt;
      final hit = it.y + _itemSize > basketTop &&
          it.y < _h - 14 &&
          it.x + _itemSize > _basketX + 4 &&
          it.x < _basketX + _basketW - 4;
      if (hit) {
        _score = math.max(0, _score + (it.coin ? 10 : -15));
        _flash = it.coin ? AppColors.gold : AppColors.error;
        _flashT = 1;
        it.coin ? HapticFeedback.selectionClick() : HapticFeedback.mediumImpact();
        return true;
      }
      return it.y > _h;
    });
    _flashT = math.max(0, _flashT - dt * 5);
    setState(() {});
  }

  Future<void> _end() async {
    _ticker.stop();
    setState(() => _phase = _Phase.ending);
    try {
      final result = await _repo.submit(widget.mission.id, {'score': _score});
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MissionResultPage.route(
        country: widget.country,
        mission: widget.mission,
        result: result,
        onRetry: () => Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => MiniGamePage(country: widget.country, mission: widget.mission),
          ),
        ),
      ));
    } on MissionException catch (e) {
      if (!mounted) return;
      setState(() => _phase = _Phase.ready);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Skor $_score tidak terkirim: ${e.message}'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  void _close() {
    _ticker.stop();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _phase == _Phase.ready,
      onPopInvoked: (didPop) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              children: [
                MissionTopBar(
                  title: 'Tangkap Koin',
                  subtitle: 'Miringkan HP ke kiri/kanan',
                  icon: Icons.close_rounded,
                  onBack: _close,
                ),
                const SizedBox(height: 12),
                _hud(),
                const SizedBox(height: 12),
                Expanded(child: _arena()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _hud() {
    final left = math.max(0, _left);
    return Row(
      children: [
        _hudBox('Waktu', left.ceil().toString(),
            color: left <= 5 && _phase == _Phase.playing ? AppColors.error : AppColors.ink),
        const SizedBox(width: 10),
        _hudBox('Skor', '$_score', color: _score >= _target ? AppColors.success : AppColors.ink),
        const SizedBox(width: 10),
        _hudBox('Target', '$_target'),
      ],
    );
  }

  Widget _hudBox(String label, String value, {Color color = AppColors.ink}) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: AppColors.ink.withOpacity(.08), blurRadius: 8)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
              Text(value, style: AppTheme.heading(20, color: color)),
            ],
          ),
        ),
      );

  Widget _arena() {
    return LayoutBuilder(
      builder: (context, box) {
        _w = box.maxWidth;
        _h = box.maxHeight;
        if (_phase == _Phase.ready && _basketX == 0) _basketX = (_w - _basketW) / 2;
        return ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: GestureDetector(
            onPanUpdate: (d) {
              if (_phase != _Phase.playing) return;
              setState(() => _basketX =
                  (_basketX + d.delta.dx).clamp(0, math.max(0, _w - _basketW)).toDouble());
            },
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFCFE8F3), Color(0xFFEAF6FA)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                const Positioned(left: 24, top: 40, child: _Cloud(w: 70)),
                const Positioned(right: 30, top: 110, child: _Cloud(w: 54)),
                for (final it in _items)
                  Positioned(
                    left: it.x,
                    top: it.y,
                    child: it.coin ? const _CoinView() : const _RockView(),
                  ),
                Positioned(
                  left: _basketX,
                  bottom: 10,
                  child: _Basket(flash: _flash, t: _flashT),
                ),
                if (_phase != _Phase.playing) _overlay(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _overlay() {
    final ending = _phase == _Phase.ending;
    return Positioned.fill(
      child: ColoredBox(
        color: AppColors.ink.withOpacity(.6),
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(ending ? Icons.hourglass_bottom_rounded : Icons.sports_esports_rounded,
                    size: 40, color: AppColors.teal),
                const SizedBox(height: 8),
                Text(ending ? 'Waktu habis!' : 'Siap?', style: AppTheme.heading(22)),
                const SizedBox(height: 8),
                Text(
                  ending
                      ? 'Skormu $_score. Mengirim hasil…'
                      : 'Tangkap koin emas dan hindari batu. Butuh $_target poin untuk menyelesaikan misi.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted, height: 1.4),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _sensorOk ? const Color(0xFFE8F6EF) : const Color(0xFFFBEFD0),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_sensorOk ? Icons.sensors_rounded : Icons.touch_app_rounded,
                          size: 16,
                          color: _sensorOk ? AppColors.success : AppColors.goldDark),
                      const SizedBox(width: 6),
                      Text(_sensorOk ? 'Accelerometer aktif' : 'Sensor tidak terbaca: geser layar',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _sensorOk ? AppColors.success : AppColors.goldDark)),
                    ],
                  ),
                ),
                if (!ending) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: _start,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.ink,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      child: const Text('Mulai'),
                    ),
                  ),
                ] else
                  const Padding(
                    padding: EdgeInsets.only(top: 14),
                    child: SizedBox(
                        width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.6)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CoinView extends StatelessWidget {
  const _CoinView();

  @override
  Widget build(BuildContext context) => Container(
        width: _MiniGamePageState._itemSize,
        height: _MiniGamePageState._itemSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(colors: [Color(0xFFFFE08A), AppColors.gold]),
          border: Border.all(color: const Color(0xFFC98F12), width: 3),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(.2), blurRadius: 5, offset: const Offset(0, 3))],
        ),
        child: const Icon(Icons.star_rounded, size: 18, color: Color(0xFFC98F12)),
      );
}

class _RockView extends StatelessWidget {
  const _RockView();

  @override
  Widget build(BuildContext context) => Container(
        width: _MiniGamePageState._itemSize,
        height: _MiniGamePageState._itemSize,
        decoration: BoxDecoration(
          color: const Color(0xFF6B7C8C),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(14),
            bottomRight: Radius.circular(18),
          ),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(.25), blurRadius: 5, offset: const Offset(0, 3))],
        ),
      );
}

class _Cloud extends StatelessWidget {
  const _Cloud({required this.w});

  final double w;

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: .8,
        child: Container(
          width: w,
          height: w * .38,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(w)),
        ),
      );
}

class _Basket extends StatelessWidget {
  const _Basket({required this.flash, required this.t});

  final Color? flash;
  final double t;

  @override
  Widget build(BuildContext context) {
    final color = Color.lerp(AppColors.teal, flash ?? AppColors.teal, t) ?? AppColors.teal;
    return Container(
      width: _MiniGamePageState._basketW,
      height: 44,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
          bottomLeft: Radius.circular(22),
          bottomRight: Radius.circular(22),
        ),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.25), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: const Icon(Icons.shopping_basket_rounded, color: Colors.white),
    );
  }
}

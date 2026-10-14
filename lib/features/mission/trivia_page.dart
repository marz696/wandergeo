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

/// Kuis trivia: 20 soal, 15 detik per soal. Penilaian resmi dilakukan server;
/// skor di layar hanya perkiraan dengan rumus yang sama.
class TriviaPage extends StatefulWidget {
  const TriviaPage({super.key, required this.country, required this.mission});

  final Country country;
  final MissionInfo mission;

  @override
  State<TriviaPage> createState() => _TriviaPageState();
}

class _TriviaPageState extends State<TriviaPage>
    with SingleTickerProviderStateMixin {
  static const _seconds = 15;

  late final MissionRepository _repo =
      MissionRepository(context.read<AuthRepository>());

  late final AnimationController _timer = AnimationController(
    vsync: this,
    duration: const Duration(seconds: _seconds),
  );

  List<QuizQuestion> _qs = const [];
  List<bool?> _marks = const [];
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  int _i = 0;
  int? _picked;
  bool _locked = false;
  int _streak = 0;
  int _bestStreak = 0;
  int _correct = 0;
  int _score = 0;
  int _lastPts = 0;
  int _ptsKey = 0;
  final List<Map<String, dynamic>> _answers = [];

  @override
  void initState() {
    super.initState();
    _timer.addStatusListener((s) {
      if (s == AnimationStatus.completed) _answer(-1);
    });
    _load();
  }

  @override
  void dispose() {
    _timer.dispose();
    super.dispose();
  }

  int get _timeLeft =>
      ((1 - _timer.value) * _seconds).ceil().clamp(0, _seconds).toInt();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final qs = await _repo.questions(widget.mission.id);
      if (!mounted) return;
      setState(() {
        _qs = qs;
        _marks = List<bool?>.filled(qs.length, null);
        _loading = false;
      });
      _timer.forward(from: 0);
    } on MissionException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  void _answer(int choice) {
    if (_locked || _qs.isEmpty) return;
    _timer.stop();
    final q = _qs[_i];
    final left = _timeLeft;
    final good = choice == q.correct;
    var pts = 0;
    if (good) {
      _streak++;
      _bestStreak = math.max(_bestStreak, _streak);
      _correct++;
      final int speedBonus = math.min<int>(5, left ~/ 3);
      final int streakBonus = math.min<int>(5, _streak - 1);
      pts = 10 + speedBonus + streakBonus;
      _score += pts;
      HapticFeedback.lightImpact();
    } else {
      _streak = 0;
      HapticFeedback.heavyImpact();
    }
    _answers.add({'question_id': q.id, 'choice': choice, 'time_left': left});
    _marks[_i] = good;
    setState(() {
      _picked = choice;
      _locked = true;
      _lastPts = pts;
      _ptsKey++;
    });
  }

  void _next() {
    if (_i == _qs.length - 1) {
      _finish();
      return;
    }
    setState(() {
      _i++;
      _picked = null;
      _locked = false;
    });
    _timer.forward(from: 0);
  }

  Future<void> _finish() async {
    setState(() => _submitting = true);
    try {
      final result =
          await _repo.submit(widget.mission.id, {'answers': _answers});
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MissionResultPage.route(
        country: widget.country,
        mission: widget.mission,
        result: result,
        bestStreak: _bestStreak,
        onRetry: () => Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) =>
                TriviaPage(country: widget.country, mission: widget.mission),
          ),
        ),
      ));
    } on MissionException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      final retry = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Gagal mengirim jawaban'),
          content: Text(
              '${e.message}\n\nJawabanmu masih tersimpan. Coba kirim lagi?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Keluar')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Kirim lagi')),
          ],
        ),
      );
      if (!mounted) return;
      retry == true ? _finish() : Navigator.of(context).pop();
    }
  }

  Future<void> _confirmQuit() async {
    _timer.stop();
    final quit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Keluar dari kuis?'),
        content: const Text('Progres kuis ini tidak akan disimpan.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Lanjut main')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (quit == true) {
      Navigator.of(context).pop();
    } else if (!_locked && !_loading) {
      _timer.forward(); // lanjutkan sisa waktu
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) _confirmQuit();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _errorView()
                  : _quiz(),
        ),
      ),
    );
  }

  Widget _errorView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded,
                  size: 44, color: AppColors.hint),
              const SizedBox(height: 10),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 14),
              FilledButton(onPressed: _load, child: const Text('Coba lagi')),
              TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Kembali')),
            ],
          ),
        ),
      );

  Widget _quiz() {
    final q = _qs[_i];
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  RoundIconButton2(onTap: _confirmQuit),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Trivia ${widget.country.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.heading(17)),
                  ),
                  _scoreChip(),
                  const SizedBox(width: 10),
                  AnimatedBuilder(
                    animation: _timer,
                    builder: (_, __) {
                      final left = _timeLeft;
                      return ProgressRing(
                        value: 1 - _timer.value,
                        size: 46,
                        stroke: 5,
                        track: AppColors.border,
                        color: left <= 5 ? AppColors.error : AppColors.teal,
                        child: Text('$left',
                            style: AppTheme.heading(14,
                                color: left <= 5
                                    ? AppColors.error
                                    : AppColors.ink)),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _segments(),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(bottom: _locked ? 230 : 24),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween<Offset>(
                                begin: const Offset(.08, 0), end: Offset.zero)
                            .animate(anim),
                        child: child,
                      ),
                    ),
                    child: Column(
                      key: ValueKey(_i),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 18),
                        _questionCard(q),
                        const SizedBox(height: 14),
                        for (var k = 0; k < q.options.length; k++)
                          _option(q, k),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        _feedback(q),
        if (_submitting)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.white.withOpacity(.85),
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }

  Widget _scoreChip() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: AppColors.ink.withOpacity(.1), blurRadius: 6)
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.stars_rounded, size: 16, color: AppColors.gold),
            const SizedBox(width: 4),
            Text('$_score',
                style: const TextStyle(
                    fontWeight: FontWeight.w800, color: AppColors.goldDark)),
          ],
        ),
      );

  Widget _segments() => Row(
        children: [
          for (var i = 0; i < _qs.length; i++)
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 7,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: _marks[i] == true
                      ? AppColors.success
                      : _marks[i] == false
                          ? AppColors.error
                          : (i == _i ? AppColors.teal : AppColors.border),
                ),
              ),
            ),
        ],
      );

  Widget _questionCard(QuizQuestion q) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
                color: AppColors.ink.withOpacity(.1),
                blurRadius: 24,
                offset: const Offset(0, 8)),
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _chip('Soal ${_i + 1} dari ${_qs.length}', AppColors.sea,
                        AppColors.deepNavy),
                    if (_streak > 1)
                      _chip('Beruntun ×$_streak', const Color(0xFFFBEFD0),
                          AppColors.goldDark,
                          icon: Icons.bolt_rounded),
                  ],
                ),
                const SizedBox(height: 14),
                Text(q.text, style: AppTheme.heading(20).copyWith(height: 1.3)),
              ],
            ),
            if (_lastPts > 0 && _locked)
              Positioned(
                right: 0,
                top: 0,
                child: TweenAnimationBuilder<double>(
                  key: ValueKey(_ptsKey),
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 900),
                  builder: (_, t, __) => Opacity(
                    opacity: (1 - t).clamp(0, 1).toDouble(),
                    child: Transform.translate(
                      offset: Offset(0, -34 * t),
                      child: Text('+$_lastPts',
                          style:
                              AppTheme.heading(18, color: AppColors.goldDark)),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );

  Widget _chip(String t, Color bg, Color fg, {IconData? icon}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: 3)
            ],
            Text(t,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
          ],
        ),
      );

  Widget _option(QuizQuestion q, int k) {
    final good = _locked && k == q.correct;
    final bad = _locked && k == _picked && k != q.correct;
    final dim = _locked && !good && !bad;
    final color =
        good ? AppColors.success : (bad ? AppColors.error : AppColors.border);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedOpacity(
        opacity: dim ? .45 : 1,
        duration: const Duration(milliseconds: 250),
        child: Material(
          color: good
              ? const Color(0xFFE8F6EF)
              : bad
                  ? const Color(0xFFFCECEA)
                  : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: color, width: 2),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: _locked ? null : () => _answer(k),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: good || bad ? color : AppColors.background,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: good || bad
                        ? Icon(good ? Icons.check_rounded : Icons.close_rounded,
                            size: 20, color: Colors.white)
                        : Text('ABCD'[k], style: AppTheme.heading(14)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(q.options[k],
                        style: const TextStyle(
                            fontSize: 15.5, fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _feedback(QuizQuestion q) {
    final good = _picked == q.correct;
    final title = good
        ? 'Benar! +$_lastPts'
        : (_picked == -1 ? 'Waktu habis' : 'Kurang tepat');
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: IgnorePointer(
        ignoring: !_locked,
        child: AnimatedSlide(
          offset: _locked ? Offset.zero : const Offset(0, 1.05),
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
          child: Container(
            padding: EdgeInsets.fromLTRB(
                20, 18, 20, 22 + MediaQuery.of(context).padding.bottom),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(color: AppColors.ink.withOpacity(.2), blurRadius: 30)
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                        good
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                        color: good ? AppColors.success : AppColors.error),
                    const SizedBox(width: 8),
                    Text(title, style: AppTheme.heading(18)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(q.explanation,
                    style: const TextStyle(
                        color: AppColors.muted, height: 1.45, fontSize: 14)),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _next,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.ink,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26)),
                      textStyle: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    child:
                        Text(_i == _qs.length - 1 ? 'Lihat hasil' : 'Lanjut'),
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

/// Tombol tutup bulat sederhana (menghindari impor tambahan).
class RoundIconButton2 extends StatelessWidget {
  const RoundIconButton2({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Keluar',
      child: Material(
        color: Colors.white,
        elevation: 4,
        shadowColor: AppColors.ink.withOpacity(.25),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: const SizedBox(
            width: 44,
            height: 44,
            child: Icon(Icons.close_rounded, color: AppColors.ink),
          ),
        ),
      ),
    );
  }
}

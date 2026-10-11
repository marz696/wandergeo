import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../routes.dart';
import 'globe_painter.dart';

/// Splash: globe berputar, pesawat mengorbit, wordmark muncul.
/// Sentuh globe untuk riak gelombang; lanjut otomatis atau tekan "Lewati".
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  static const _autoContinue = Duration(milliseconds: 5000);

  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..forward();
  late final AnimationController _orbit =
      AnimationController(vsync: this, duration: const Duration(seconds: 5));
  late final AnimationController _scroll =
      AnimationController(vsync: this, duration: const Duration(seconds: 10))
        ..repeat();
  late final AnimationController _ping = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  Animation<double> _iv(double a, double b, [Curve c = Curves.easeOut]) =>
      CurvedAnimation(parent: _enter, curve: Interval(a, b, curve: c));

  late final Animation<double> _globe = _iv(0, .27, Curves.easeOutBack);
  late final Animation<double> _orbitFade = _iv(.23, .38);
  late final Animation<double> _title = _iv(.54, .77);
  late final Animation<double> _tagline = _iv(.65, .88);
  late final Animation<double> _skip = _iv(.77, 1);

  final List<Timer> _timers = [];
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _timers.add(Timer(const Duration(milliseconds: 600), () {
      if (mounted) _orbit.repeat();
    }));
    _timers.add(Timer(_autoContinue, _goLogin));
  }

  void _goLogin() {
    if (_leaving || !mounted) return;
    _leaving = true;
    Navigator.of(context).pushReplacementNamed(AppRoutes.login);
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _enter.dispose();
    _orbit.dispose();
    _scroll.dispose();
    _ping.dispose();
    super.dispose();
  }

  Widget _fadeUp(Animation<double> a, Widget child) => FadeTransition(
        opacity: a,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, .4), end: Offset.zero)
              .animate(a),
          child: child,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 80),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 240,
                      height: 240,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _ping.forward(from: 0),
                              child: Semantics(
                                label: 'Globe dengan pesawat yang mengorbit',
                                child: CustomPaint(
                                  painter: GlobePainter(
                                    intro: _globe,
                                    orbitFade: _orbitFade,
                                    orbit: _orbit,
                                    scroll: _scroll,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          IgnorePointer(
                            child: Center(
                              child: AnimatedBuilder(
                                animation: _ping,
                                builder: (_, __) {
                                  final t = _ping.value;
                                  if (t == 0) return const SizedBox.shrink();
                                  return Opacity(
                                    opacity: (1 - t) * .9,
                                    child: Transform.scale(
                                      scale: .9 + 1.1 * t,
                                      child: Container(
                                        width: 124,
                                        height: 124,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: AppColors.teal,
                                            width: 3,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    _fadeUp(
                      _title,
                      Text.rich(
                        TextSpan(children: [
                          TextSpan(text: 'Wander', style: AppTheme.heading(36)),
                          TextSpan(
                            text: 'Geo',
                            style: AppTheme.heading(36, color: AppColors.teal),
                          ),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _fadeUp(
                      _tagline,
                      const Text(
                        'Jelajahi dunia, kumpulkan stempelmu',
                        style: TextStyle(fontSize: 15, color: AppColors.muted),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 56),
                child: FadeTransition(
                  opacity: _skip,
                  child: OutlinedButton(
                    onPressed: _goLogin,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.ink,
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: AppColors.border, width: 1.5),
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      shape: const StadiumBorder(),
                    ),
                    child: const Text(
                      'Lewati',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

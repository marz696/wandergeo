import 'package:flutter/material.dart';

import '../../core/services/currency_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/round_icon_button.dart';
import 'widgets/currency_card.dart';
import 'widgets/world_time_card.dart';

/// Alat Perjalanan: konversi mata uang (kurs online + cache SQLite)
/// dan konversi waktu WIB / WITA / WIT / London.
class AlatPerjalananPage extends StatefulWidget {
  const AlatPerjalananPage({super.key, this.initialCurrency});

  /// Mata uang tujuan awal (mis. dari negara yang sedang dibuka).
  final String? initialCurrency;

  static Route<void> route({String? currency}) => PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 380),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (_, __, ___) => AlatPerjalananPage(initialCurrency: currency),
        transitionsBuilder: (_, anim, __, child) {
          final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, .06),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      );

  @override
  State<AlatPerjalananPage> createState() => _AlatPerjalananPageState();
}

class _AlatPerjalananPageState extends State<AlatPerjalananPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..forward();

  late final List<Animation<double>> _stag = List.generate(3, (i) {
    final start = i * .18;
    return CurvedAnimation(
      parent: _enter,
      curve: Interval(start, start + .55, curve: Curves.easeOutCubic),
    );
  });

  RateTable? _table;
  RateStatus _status = RateStatus.loading;

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

  Future<void> _load({bool force = false}) async {
    setState(() => _status = RateStatus.loading);
    final (table, status) = await CurrencyService.instance.load(force: force);
    if (!mounted) return;
    setState(() {
      _table = table ?? _table;
      _status = status;
    });
  }

  Widget _reveal(int i, Widget child) => FadeTransition(
        opacity: _stag[i],
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, .1), end: Offset.zero)
              .animate(_stag[i]),
          child: child,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusScope.of(context).unfocus(),
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _reveal(
                0,
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
                          Text('Alat Perjalanan', style: AppTheme.heading(24)),
                          const Text(
                            'Kurs mata uang dan waktu dunia',
                            style: TextStyle(
                                fontSize: 12.5, color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _reveal(
                1,
                CurrencyCard(
                  table: _table,
                  status: _status,
                  initialTo: widget.initialCurrency,
                  onRefresh: () => _load(force: true),
                ),
              ),
              const SizedBox(height: 14),
              _reveal(2, const WorldTimeCard()),
            ],
          ),
        ),
      ),
    );
  }
}

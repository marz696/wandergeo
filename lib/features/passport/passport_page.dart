import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../auth/auth_repository.dart';
import 'data/passport_repository.dart';
import 'models/passport_models.dart';
import 'widgets/block_sheet.dart';
import 'widgets/chain_card.dart';
import 'widgets/passport_hero.dart';
import 'widgets/passport_ui.dart';
import 'widgets/stamp_card.dart';

/// Paspor Digital: koleksi stempel negara yang sudah diselesaikan. Tiap stempel
/// adalah blok blockchain sederhana; server memverifikasi seluruh rantai.
///
/// Palet sengaja dibatasi: navy (ink) + netral sebagai dasar, emas hanya untuk
/// aksen kecil di sampul, teal untuk ikon, dan merah tinta hanya pada stempel
/// (sesuai StampBadge). Hijau/merah error dipakai khusus untuk status validasi.
class PassportPage extends StatefulWidget {
  const PassportPage({super.key, this.refresh});

  /// Dinaikkan oleh MainShell tiap tab ini dibuka agar data selalu segar.
  final ValueListenable<int>? refresh;

  @override
  State<PassportPage> createState() => _PassportPageState();
}

class _PassportPageState extends State<PassportPage> {
  late final PassportRepository _repo;
  PassportData? _data;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _repo = PassportRepository(context.read<AuthRepository>());
    widget.refresh?.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    widget.refresh?.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await _repo.load();
      if (!mounted) return;
      setState(() => _data = d);
    } on PassportException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Gagal memuat paspor.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final navSpace = 92 + mq.padding.bottom;
    final user = context.read<AuthRepository>().currentUser;
    final d = _data;
    final stamps = d?.blocks.where((b) => !b.isGenesis).toList() ??
        const <PassportBlock>[];
    final total = d?.totalCountries ?? 0;
    final slots = math.max(0, total - stamps.length);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.teal,
        backgroundColor: Colors.white,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(20, mq.padding.top + 16, 20, navSpace + 24),
          children: [
            Text('Paspor Digital', style: AppTheme.heading(26)),
            const SizedBox(height: 2),
            const Text(
              'Koleksi stempel petualanganmu',
              style: TextStyle(color: AppColors.muted, fontSize: 13.5),
            ),
            const SizedBox(height: 16),
            PassportHero(name: user?.displayName ?? '-', data: d, loading: _loading),
            const SizedBox(height: 22),
            if (_error != null && d == null)
              PassportErrorCard(message: _error!, onRetry: _load)
            else if (d == null)
              const PassportSkeleton()
            else ...[
              if (_error != null) ...[
                PassportErrorCard(message: _error!, onRetry: _load),
                const SizedBox(height: 16),
              ],
              PassportSectionHeader(
                title: 'Stempel',
                badge: total > 0 ? '${stamps.length} dari $total' : null,
              ),
              const SizedBox(height: 4),
              Text(
                stamps.isEmpty
                    ? 'Selesaikan misi Trivia dan Kuliner & Budaya di sebuah '
                        'negara untuk mendapat stempel pertamamu.'
                    : 'Ketuk stempel untuk melihat detail bloknya.',
                style: const TextStyle(
                    color: AppColors.muted, fontSize: 13.5, height: 1.4),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: .86,
                children: [
                  for (var i = 0; i < stamps.length; i++)
                    PassportReveal(
                      index: i,
                      child: StampCard(
                        block: stamps[i],
                        tilt: i.isEven ? -.06 : .05,
                        onTap: () => _showBlock(stamps[i]),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 26),
              const PassportSectionHeader(title: 'Rantai blok'),
              const SizedBox(height: 4),
              const Text(
                'Setiap blok menyimpan hash blok sebelumnya. Mengubah satu blok '
                'merusak semua blok sesudahnya.',
                style: TextStyle(
                    color: AppColors.muted, fontSize: 13.5, height: 1.4),
              ),
              const SizedBox(height: 12),
              ChainCard(blocks: d.blocks, onTap: _showBlock),
            ],
          ],
        ),
      ),
    );
  }

  void _showBlock(PassportBlock b) {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => BlockSheet(block: b),
    );
  }
}

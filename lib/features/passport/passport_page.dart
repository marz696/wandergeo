import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../auth/auth_repository.dart';
import 'data/passport_repository.dart';
import 'models/passport_models.dart';

/// Paspor Digital: koleksi stempel negara yang sudah diselesaikan. Tiap stempel
/// adalah blok blockchain sederhana; server memverifikasi seluruh rantai.
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
    final stamps = d?.blocks.where((b) => !b.isGenesis).toList() ?? const [];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(20, mq.padding.top + 16, 20, navSpace + 24),
          children: [
            Text('Paspor Digital', style: AppTheme.heading(24)),
            const SizedBox(height: 14),
            _Hero(name: user?.displayName ?? '-', data: d, loading: _loading),
            const SizedBox(height: 18),
            if (_error != null && d == null)
              _ErrorCard(message: _error!, onRetry: _load)
            else if (d == null)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              if (_error != null) ...[
                _ErrorCard(message: _error!, onRetry: _load),
                const SizedBox(height: 14),
              ],
              Text('Stempel', style: AppTheme.heading(17)),
              const SizedBox(height: 10),
              if (stamps.isEmpty)
                const _EmptyCard()
              else
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: .88,
                  children: [
                    for (final b in stamps)
                      _StampCard(block: b, onTap: () => _showBlock(b)),
                  ],
                ),
              const SizedBox(height: 22),
              Text('Rantai blok', style: AppTheme.heading(17)),
              const SizedBox(height: 4),
              const Text(
                'Setiap blok menyimpan hash blok sebelumnya. Mengubah satu blok '
                'merusak semua blok sesudahnya.',
                style: TextStyle(color: AppColors.muted, height: 1.4),
              ),
              const SizedBox(height: 10),
              for (final b in d.blocks) _ChainRow(block: b, onTap: () => _showBlock(b)),
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
      builder: (_) => _BlockSheet(block: b),
    );
  }
}

String _short(String h) => h.length > 14 ? '${h.substring(0, 8)}…${h.substring(h.length - 6)}' : h;

String _date(DateTime t) {
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
  return '${t.day} ${m[t.month - 1]} ${t.year}';
}

class _Hero extends StatelessWidget {
  const _Hero({required this.name, required this.data, required this.loading});

  final String name;
  final PassportData? data;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final d = data;
    final valid = d?.valid;
    final color = valid == null
        ? AppColors.lightTeal
        : valid
            ? const Color(0xFF7BE0A8)
            : const Color(0xFFFFB4AB);
    final label = loading && d == null
        ? 'Memverifikasi…'
        : valid == null
            ? 'Belum terverifikasi'
            : valid
                ? 'Rantai valid'
                : 'Blok #${d!.brokenAt} tidak cocok';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.deepNavy, AppColors.ink],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withOpacity(.10),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('PASPOR AGEN',
              style: TextStyle(
                  color: AppColors.gold, fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(name, style: AppTheme.heading(22, color: Colors.white)),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${d?.stamps ?? 0}', style: AppTheme.heading(38, color: Colors.white)),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Text('/ ${d?.totalCountries ?? 0} negara',
                    style: const TextStyle(color: AppColors.lightTeal)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.10),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(valid == false ? Icons.gpp_bad_rounded : Icons.verified_rounded,
                    color: color, size: 18),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Flag extends StatelessWidget {
  const _Flag({required this.url, this.size = 44});
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = Icon(Icons.flag_rounded, color: AppColors.teal, size: size * .6);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: size * 1.35,
        height: size,
        child: url == null
            ? ColoredBox(color: AppColors.sea, child: fallback)
            : Image.network(url!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => ColoredBox(color: AppColors.sea, child: fallback)),
      ),
    );
  }
}

class _StampCard extends StatelessWidget {
  const _StampCard({required this.block, required this.onTap});
  final PassportBlock block;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ok = block.valid;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: ok ? AppColors.gold.withOpacity(.55) : AppColors.error, width: 1.4),
            boxShadow: [
              BoxShadow(color: AppColors.ink.withOpacity(.10), blurRadius: 18, offset: const Offset(0, 8)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _Flag(url: block.flagUrl, size: 34),
                  Icon(ok ? Icons.verified_rounded : Icons.gpp_bad_rounded,
                      size: 20, color: ok ? AppColors.success : AppColors.error),
                ],
              ),
              const Spacer(),
              Text(block.countryName ?? block.countryCode ?? '-',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.heading(15)),
              const SizedBox(height: 2),
              Text(_date(block.timestamp),
                  style: const TextStyle(color: AppColors.hint, fontSize: 12)),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.star_rounded, size: 16, color: AppColors.goldDeep),
                  const SizedBox(width: 3),
                  Text('${block.score}',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.goldDark)),
                  const Spacer(),
                  Text('#${block.index}',
                      style: const TextStyle(color: AppColors.hint, fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChainRow extends StatelessWidget {
  const _ChainRow({required this.block, required this.onTap});
  final PassportBlock block;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ok = block.valid;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ok ? AppColors.sea : const Color(0xFFFCEBE9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('#${block.index}',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: ok ? AppColors.teal : AppColors.error)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(block.isGenesis ? 'Blok genesis' : (block.countryName ?? '-'),
                      style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)),
                  Text(_short(block.hash),
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 12, color: AppColors.hint)),
                ],
              ),
            ),
            Icon(ok ? Icons.link_rounded : Icons.link_off_rounded,
                color: ok ? AppColors.success : AppColors.error, size: 20),
          ],
        ),
      ),
    );
  }
}

class _BlockSheet extends StatelessWidget {
  const _BlockSheet({required this.block});
  final PassportBlock block;

  @override
  Widget build(BuildContext context) {
    Widget row(String k, String v, {bool mono = false}) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(k, style: const TextStyle(color: AppColors.hint, fontSize: 12)),
              const SizedBox(height: 2),
              SelectableText(v,
                  style: TextStyle(
                      color: AppColors.ink,
                      fontFamily: mono ? 'monospace' : null,
                      fontSize: mono ? 12 : 14)),
            ],
          ),
        );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 12),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(block.isGenesis ? 'Blok genesis #0' : 'Blok #${block.index} · ${block.countryName}',
                  style: AppTheme.heading(18)),
              const SizedBox(height: 4),
              Text(block.valid ? 'Hash cocok dengan isi blok' : 'Hash TIDAK cocok: blok ini diubah',
                  style: TextStyle(
                      color: block.valid ? AppColors.success : AppColors.error,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              if (!block.isGenesis) row('Skor negara', '${block.score}'),
              row('Waktu', block.timestamp.toString().split('.').first),
              row('Hash sebelumnya', block.previousHash, mono: true),
              row('Hash blok ini', block.hash, mono: true),
              row('Nonce (proof-of-work, awalan "00")', '${block.nonce}'),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: AppColors.ink.withOpacity(.10), blurRadius: 18, offset: const Offset(0, 8)),
          ],
        ),
        child: const Text(
          'Belum ada stempel. Selesaikan misi Trivia dan Kuliner & Budaya di sebuah '
          'negara untuk mendapat stempel pertamamu.',
          style: TextStyle(color: AppColors.muted, height: 1.4),
        ),
      );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFCEBE9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_rounded, color: AppColors.error),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(color: AppColors.ink))),
            TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
          ],
        ),
      );
}

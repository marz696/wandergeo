import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../auth/auth_repository.dart';
import 'data/feedback_repository.dart';
import 'feedback_all_page.dart';
import 'widgets/feedback_ui.dart';
import 'widgets/rating_face.dart';

/// Riwayat kiriman milik pengguna yang sedang masuk (semua pengguna bisa
/// melihat miliknya sendiri), plus tombol ke daftar semua kesan & pesan.
class FeedbackHistoryPage extends StatefulWidget {
  const FeedbackHistoryPage({super.key});

  @override
  State<FeedbackHistoryPage> createState() => _FeedbackHistoryPageState();
}

class _FeedbackHistoryPageState extends State<FeedbackHistoryPage> {
  late final FeedbackRepository _repo;
  List<FeedbackEntry> _items = const [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _repo = FeedbackRepository(context.read<AuthRepository>());
    _load();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
      ));
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _repo.list();
      if (mounted) setState(() => _items = list);
    } on FeedbackException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Gagal memuat riwayat.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(FeedbackEntry e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Hapus kiriman ini?', style: AppTheme.heading(18)),
        content: const Text(
          'Kesan dan saran ini akan dihapus permanen.',
          style: TextStyle(color: AppColors.muted, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.delete(e.id);
      if (!mounted) return;
      setState(() => _items = _items.where((x) => x.id != e.id).toList());
      _toast('Kiriman dihapus.');
    } on FeedbackException catch (err) {
      _toast(err.message);
    } catch (_) {
      _toast('Gagal menghapus. Coba lagi.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              color: AppColors.teal,
              onRefresh: _load,
              child: ListView(
                physics: const ClampingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                padding: EdgeInsets.fromLTRB(24, mq.padding.top + 16, 24, 16),
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [FeedbackEyebrow('KESAN & SARAN'), CloseCircle()],
                  ),
                  const SizedBox(height: 18),
                  Text('Riwayat kirimanmu',
                      style: AppTheme.heading(24, weight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  const Text(
                    'Semua kesan dan saran yang pernah kamu kirim.',
                    style: TextStyle(color: AppColors.muted, fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  if (_error != null && _items.isEmpty)
                    FeedbackErrorCard(message: _error!, onRetry: _load)
                  else if (_loading && _items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_items.isEmpty)
                    const FeedbackEmptyCard(
                      'Belum ada kiriman. Kesan dan saran yang kamu kirim akan muncul di sini.',
                    )
                  else
                    for (final e in _items) _EntryCard(entry: e, onDelete: () => _delete(e)),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(24, 8, 24, mq.padding.bottom + 24),
            child: FeedbackButton(
              label: 'SEMUA KESAN & PESAN',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const FeedbackAllPage()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry, required this.onDelete});

  final FeedbackEntry entry;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final rating = entry.rating;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 12, 4, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (rating != null) RatingFace(level: rating, size: 32),
              const Spacer(),
              Text(feedbackDate(entry.createdAt),
                  style: const TextStyle(color: AppColors.hint, fontSize: 12)),
              IconButton(
                tooltip: 'Hapus',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (entry.tags.isNotEmpty)
                  Text(entry.tags.join(' · '),
                      style: const TextStyle(
                          color: AppColors.goldDark, fontWeight: FontWeight.w700, fontSize: 12)),
                if (entry.message.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(entry.message,
                      style: const TextStyle(color: AppColors.ink, height: 1.4)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

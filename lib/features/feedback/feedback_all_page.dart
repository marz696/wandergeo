import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../auth/auth_repository.dart';
import 'data/feedback_repository.dart';
import 'widgets/feedback_ui.dart';
import 'widgets/rating_face.dart';

/// Kesan dan pesan semua mahasiswa untuk mata kuliah PAM Mobile.
class FeedbackAllPage extends StatefulWidget {
  const FeedbackAllPage({super.key});

  @override
  State<FeedbackAllPage> createState() => _FeedbackAllPageState();
}

class _FeedbackAllPageState extends State<FeedbackAllPage> {
  late final FeedbackRepository _repo;
  FeedbackBoard? _board;
  FeedbackSort _sort = FeedbackSort.latest;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _repo = FeedbackRepository(context.read<AuthRepository>());
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final b = await _repo.listAll(sort: _sort);
      if (mounted) setState(() => _board = b);
    } on FeedbackException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Gagal memuat kesan dan pesan.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setSort(FeedbackSort s) {
    if (s == _sort) return;
    setState(() => _sort = s);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final items = _board?.items ?? const <PublicFeedback>[];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.teal,
        onRefresh: _load,
        child: ListView(
          physics: const ClampingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          padding: EdgeInsets.fromLTRB(24, mq.padding.top + 16, 24, mq.padding.bottom + 24),
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [FeedbackEyebrow('PAM MOBILE'), CloseCircle()],
            ),
            const SizedBox(height: 18),
            Text('Kesan & pesan mata kuliah',
                style: AppTheme.heading(24, weight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              _board == null
                  ? 'Dari semua mahasiswa'
                  : 'Dari semua mahasiswa · ${_board!.total} kiriman',
              style: const TextStyle(color: AppColors.muted, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                TagChip(
                  label: 'Terbaru',
                  selected: _sort == FeedbackSort.latest,
                  onTap: () => _setSort(FeedbackSort.latest),
                ),
                const SizedBox(width: 10),
                TagChip(
                  label: 'Rating tertinggi',
                  selected: _sort == FeedbackSort.rating,
                  onTap: () => _setSort(FeedbackSort.rating),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_error != null && items.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: FeedbackErrorCard(message: _error!, onRetry: _load),
              )
            else if (_loading && items.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: FeedbackEmptyCard('Belum ada kesan dan pesan yang masuk.'),
              )
            else
              for (var i = 0; i < items.length; i++)
                _Row(item: items[i], last: i == items.length - 1),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.item, required this.last});

  final PublicFeedback item;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final avatar = item.avatarUrl;
    final text = item.message.isNotEmpty ? item.message : item.tags.join(' · ');
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: last ? null : const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.border,
            backgroundImage: avatar != null && avatar.isNotEmpty ? NetworkImage(avatar) : null,
            child: avatar == null || avatar.isEmpty
                ? Text(
                    item.name.isEmpty ? '?' : item.name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                        color: AppColors.ink, fontSize: 13, fontWeight: FontWeight.w700),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                    if (item.rating != null) RatingFace(level: item.rating!, size: 24),
                  ],
                ),
                Text(feedbackDate(item.createdAt),
                    style: const TextStyle(color: AppColors.hint, fontSize: 12)),
                if (text.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(text, style: const TextStyle(color: AppColors.ink, height: 1.4)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

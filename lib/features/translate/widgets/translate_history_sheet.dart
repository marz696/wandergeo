import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../data/translate_history_repository.dart';

Future<void> showTranslateHistorySheet(
  BuildContext context, {
  required TranslateHistoryRepository repo,
  required String userId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _HistorySheet(repo: repo, userId: userId),
  );
}

class _HistorySheet extends StatefulWidget {
  const _HistorySheet({required this.repo, required this.userId});

  final TranslateHistoryRepository repo;
  final String userId;

  @override
  State<_HistorySheet> createState() => _HistorySheetState();
}

class _HistorySheetState extends State<_HistorySheet> {
  List<TranslateEntry>? _items;
  int? _copiedId;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await widget.repo.list(widget.userId);
    if (!mounted) return;
    setState(() => _items = items);
  }

  String _date(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.day} ${_months[d.month - 1]}, ${two(d.hour)}.${two(d.minute)}';
  }

  Future<void> _copy(TranslateEntry e) async {
    await Clipboard.setData(ClipboardData(text: e.translated));
    if (!mounted) return;
    setState(() => _copiedId = e.id);
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted && _copiedId == e.id) setState(() => _copiedId = null);
    });
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Hapus semua riwayat?', style: AppTheme.heading(18)),
        content: const Text(
          'Riwayat terjemahan di perangkat ini akan dihapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await widget.repo.clear(widget.userId);
    if (!mounted) return;
    setState(() => _items = []);
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * .75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Riwayat terjemahan',
                      style: AppTheme.heading(18),
                    ),
                  ),
                  if (items != null && items.isNotEmpty)
                    TextButton(
                      onPressed: _clear,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.muted,
                      ),
                      child: const Text('Hapus semua'),
                    ),
                ],
              ),
            ),
            if (items == null)
              const Padding(
                padding: EdgeInsets.all(32),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.ink,
                  ),
                ),
              )
            else if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 12, 24, 36),
                child: Text(
                  'Belum ada riwayat. Hasil terjemahan yang kamu buat akan tersimpan di sini dan tetap bisa dibaca tanpa internet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: AppColors.muted,
                    height: 1.45,
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(20, 4, 12, 20),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(
                    height: 24,
                    color: AppColors.border,
                  ),
                  itemBuilder: (_, i) {
                    final e = items[i];
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                e.translated,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                e.original,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.muted,
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Dari ${e.sourceLabel}, ${_date(e.createdAt)}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.hint,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Salin terjemahan',
                          onPressed: () => _copy(e),
                          icon: Icon(
                            _copiedId == e.id
                                ? Icons.check_rounded
                                : Icons.copy_rounded,
                            size: 20,
                            color: _copiedId == e.id
                                ? AppColors.success
                                : AppColors.muted,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

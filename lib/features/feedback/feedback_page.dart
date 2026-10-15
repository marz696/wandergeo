import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/primary_button.dart';
import '../auth/auth_repository.dart';
import 'data/feedback_repository.dart';

/// Kesan dan saran untuk mata kuliah Pemrograman Aplikasi Mobile. Data disimpan
/// di tabel `feedbacks`; pengguna melihat dan bisa menghapus kiriman miliknya.
class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  static const _max = 1000;

  late final FeedbackRepository _repo;
  final _impression = TextEditingController();
  final _suggestion = TextEditingController();

  List<FeedbackEntry> _items = const [];
  String? _error;
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _repo = FeedbackRepository(context.read<AuthRepository>());
    _load();
  }

  @override
  void dispose() {
    _impression.dispose();
    _suggestion.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.ink,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 110),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
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

  Future<void> _send() async {
    final impression = _impression.text.trim();
    if (impression.length < 5) {
      _toast('Tulis kesanmu dulu, minimal 5 karakter.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _sending = true);
    try {
      final entry = await _repo.save(
        impression: impression,
        suggestion: _suggestion.text.trim(),
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      _impression.clear();
      _suggestion.clear();
      setState(() => _items = [entry, ..._items]);
      _toast('Terima kasih! Kesan dan sarannya tersimpan.');
    } on FeedbackException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('Gagal mengirim. Coba lagi.');
    } finally {
      if (mounted) setState(() => _sending = false);
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
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
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

  InputDecoration _decoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.hint),
        filled: true,
        fillColor: AppColors.field,
        counterStyle: const TextStyle(color: AppColors.hint, fontSize: 12),
        contentPadding: const EdgeInsets.all(16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.teal, width: 1.4),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final navSpace = 92 + mq.padding.bottom;
    final name = context.read<AuthRepository>().currentUser?.displayName ?? '-';

    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(20, mq.padding.top + 16, 20, navSpace + 24),
          children: [
            Text('Kesan dan Saran', style: AppTheme.heading(24)),
            const SizedBox(height: 14),
            Container(
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
                  const Text(
                    'PEMROGRAMAN APLIKASI MOBILE',
                    style: TextStyle(
                      color: AppColors.gold,
                      fontSize: 12,
                      letterSpacing: 1.6,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Halo, $name',
                    style: AppTheme.heading(20, color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Ceritakan kesanmu selama mengikuti mata kuliah ini dan '
                    'saran untuk perbaikan ke depan.',
                    style: TextStyle(color: AppColors.lightTeal, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.ink.withOpacity(.10),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Kesan', style: AppTheme.heading(16)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _impression,
                    enabled: !_sending,
                    maxLength: _max,
                    minLines: 3,
                    maxLines: 6,
                    textCapitalization: TextCapitalization.sentences,
                    decoration:
                        _decoration('Apa yang kamu rasakan dan pelajari?'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text('Saran', style: AppTheme.heading(16)),
                      const SizedBox(width: 8),
                      const Text('(opsional)',
                          style: TextStyle(color: AppColors.hint, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _suggestion,
                    enabled: !_sending,
                    maxLength: _max,
                    minLines: 3,
                    maxLines: 6,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: _decoration('Apa yang sebaiknya diperbaiki?'),
                  ),
                  const SizedBox(height: 14),
                  PrimaryButton(
                    label: 'Kirim',
                    loading: _sending,
                    onPressed: _send,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('Riwayat kirimanmu', style: AppTheme.heading(17)),
            const SizedBox(height: 10),
            if (_error != null && _items.isEmpty)
              _ErrorCard(message: _error!, onRetry: _load)
            else if (_loading && _items.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_items.isEmpty)
              const _EmptyCard()
            else
              for (final e in _items)
                _EntryCard(entry: e, onDelete: () => _delete(e)),
          ],
        ),
      ),
    );
  }
}

String _date(DateTime t) {
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
  final hh = t.hour.toString().padLeft(2, '0');
  final mm = t.minute.toString().padLeft(2, '0');
  return '${t.day} ${m[t.month - 1]} ${t.year}, $hh.$mm';
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry, required this.onDelete});

  final FeedbackEntry entry;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final suggestion = entry.suggestion;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(18, 14, 8, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withOpacity(.10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _date(entry.createdAt),
                  style: const TextStyle(color: AppColors.hint, fontSize: 12),
                ),
              ),
              IconButton(
                tooltip: 'Hapus',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded,
                    color: AppColors.error, size: 22),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Kesan',
                    style: TextStyle(
                        color: AppColors.teal,
                        fontWeight: FontWeight.w700,
                        fontSize: 12)),
                const SizedBox(height: 2),
                Text(entry.impression,
                    style: const TextStyle(color: AppColors.ink, height: 1.4)),
                if (suggestion != null && suggestion.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Saran',
                      style: TextStyle(
                          color: AppColors.goldDark,
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(suggestion,
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

class _EmptyCard extends StatelessWidget {
  const _EmptyCard();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'Belum ada kiriman. Kesan dan saran yang kamu kirim akan muncul di sini.',
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
            Expanded(
              child: Text(message, style: const TextStyle(color: AppColors.ink)),
            ),
            TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
          ],
        ),
      );
}
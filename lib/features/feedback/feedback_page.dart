import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../auth/auth_repository.dart';
import 'data/feedback_repository.dart';
import 'feedback_history_page.dart';
import 'widgets/feedback_ui.dart';
import 'widgets/rating_face.dart';

/// Tab Kesan dan Saran untuk mata kuliah Pemrograman Aplikasi Mobile:
/// pilih wajah (wajib), pilih chip, lalu tulis teks tambahan (opsional).
/// Riwayat kiriman dan daftar semua kesan dibuka dari tombol "Riwayat".
class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  static const _max = 1000;

  late final FeedbackRepository _repo;
  final _message = TextEditingController();
  final _tags = <String>{};
  int _rating = 0;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _repo = FeedbackRepository(context.read<AuthRepository>());
  }

  @override
  void dispose() {
    _message.dispose();
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

  String get _prompt {
    if (_rating == 0) return 'Pilih wajah yang paling mewakili kesanmu.';
    if (_rating <= 2) return 'Maaf ya. Apa yang kurang?';
    if (_rating == 3) return 'Oke. Apa yang bisa lebih baik?';
    return 'Senang! Apa bagian favoritmu?';
  }

  Future<void> _send() async {
    if (_rating == 0) return;
    FocusScope.of(context).unfocus();
    setState(() => _sending = true);
    try {
      await _repo.save(
        rating: _rating,
        tags: kFeedbackTags.where(_tags.contains).toList(),
        message: _message.text.trim(),
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _rating = 0;
        _tags.clear();
        _message.clear();
      });
      _toast('Terima kasih! Kesan dan sarannya tersimpan.');
    } on FeedbackException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('Gagal mengirim. Coba lagi.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _openHistory() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const FeedbackHistoryPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final navSpace = 92 + mq.padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: ListView(
        physics: const ClampingScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(24, mq.padding.top + 16, 24, navSpace + 24),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const FeedbackEyebrow('KESAN & SARAN'),
              TagChip(label: 'Riwayat', onTap: _openHistory),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Bagaimana kesanmu di mata kuliah PAM Mobile?',
            style: AppTheme.heading(24, weight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(_prompt, style: const TextStyle(color: AppColors.muted, fontSize: 14)),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 1; i <= 5; i++)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _sending ? null : () => setState(() => _rating = i),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: RatingFace(level: i, selected: _rating == 0 || _rating == i),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final t in kFeedbackTags)
                TagChip(
                  label: t,
                  selected: _tags.contains(t),
                  onTap: _sending
                      ? null
                      : () => setState(() {
                            if (!_tags.remove(t)) _tags.add(t);
                          }),
                ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 20),
          Text('Ada yang ingin ditambahkan?', style: AppTheme.heading(18)),
          const SizedBox(height: 12),
          TextField(
            controller: _message,
            enabled: !_sending,
            maxLength: _max,
            minLines: 4,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Tulis kesan dan saranmu di sini',
              hintStyle: const TextStyle(color: AppColors.hint),
              filled: true,
              fillColor: Colors.white,
              counterStyle: const TextStyle(color: AppColors.hint, fontSize: 11),
              contentPadding: const EdgeInsets.all(14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.teal, width: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 16),
          FeedbackButton(
            label: 'KIRIM',
            loading: _sending,
            onPressed: _rating == 0 ? null : _send,
          ),
        ],
      ),
    );
  }
}

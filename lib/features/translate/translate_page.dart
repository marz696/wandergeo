import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/services/ocr_service.dart';
import '../../core/services/translate_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/round_icon_button.dart';
import '../auth/auth_repository.dart';
import 'data/translate_history_repository.dart';
import 'widgets/scan_painters.dart';
import 'widgets/translate_history_sheet.dart';

enum _Stage { idle, reading, downloading, translating, done, error }

class _Pair {
  const _Pair(this.original, this.translated, this.box);

  final String original;
  final String translated;
  final Rect box;
}

/// Terjemah Kamera: foto teks (papan, menu, label), dibaca dengan ML Kit,
/// lalu diterjemahkan ke bahasa Indonesia. Semua proses berjalan di perangkat.
class TranslatePage extends StatefulWidget {
  const TranslatePage({super.key});

  static Route<void> route() => PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 380),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (_, __, ___) => const TranslatePage(),
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
  State<TranslatePage> createState() => _TranslatePageState();
}

class _TranslatePageState extends State<TranslatePage>
    with TickerProviderStateMixin {
  final _picker = ImagePicker();
  final _ocr = OcrService();
  final _translator = TranslateService();
  final _history = TranslateHistoryRepository();

  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  late final List<Animation<double>> _stag = List.generate(3, (i) {
    final start = i * .16;
    return CurvedAnimation(
      parent: _enter,
      curve: Interval(start, start + .5, curve: Curves.easeOutCubic),
    );
  });

  // Garis pindai di atas foto saat proses berjalan.
  late final AnimationController _scan = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  SourceLanguage _source = kSourceLanguages.first;
  _Stage _stage = _Stage.idle;
  String? _photoPath;
  Size? _photoSize;
  List<_Pair> _pairs = const [];
  int? _selected;
  String _message = '';

  bool get _busy =>
      _stage == _Stage.reading ||
      _stage == _Stage.downloading ||
      _stage == _Stage.translating;

  String get _userId =>
      context.read<AuthRepository>().currentUser?.id ?? 'guest';

  @override
  void dispose() {
    _enter.dispose();
    _scan.dispose();
    super.dispose();
  }

  Widget _reveal(int i, Widget child) => FadeTransition(
        opacity: _stag[i],
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, .1), end: Offset.zero)
              .animate(_stag[i]),
          child: child,
        ),
      );

  void _toast(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        backgroundColor: AppColors.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ));
  }

  Future<ui.Size?> _imageSize(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final size = Size(
        frame.image.width.toDouble(),
        frame.image.height.toDouble(),
      );
      frame.image.dispose();
      codec.dispose();
      return size;
    } catch (_) {
      return null;
    }
  }

  Future<void> _pick(ImageSource source) async {
    if (_busy) return;
    HapticFeedback.selectionClick();
    XFile? file;
    try {
      file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 90,
      );
    } catch (_) {
      _fail(
        'Kamera atau galeri tidak bisa dibuka. Periksa izin aplikasi di pengaturan perangkat.',
      );
      return;
    }
    if (file == null) return;
    await _process(file.path);
  }

  Future<void> _process(String path) async {
    final source = _source;
    final userId = _userId;
    setState(() {
      _photoPath = path;
      _photoSize = null;
      _pairs = const [];
      _selected = null;
      _stage = _Stage.reading;
    });
    _scan.repeat();

    try {
      final size = await _imageSize(path);
      if (!mounted) return;
      setState(() => _photoSize = size);

      final blocks = await _ocr.read(path);
      if (!mounted) return;
      if (blocks.isEmpty) {
        _fail(
          'Tidak ada teks yang terbaca. Dekatkan kamera atau cari tempat yang lebih terang. Aksara Thai, Khmer, Lao, dan Myanmar belum didukung.',
        );
        return;
      }

      if (!await _translator.modelsReady(source.language)) {
        if (!mounted) return;
        setState(() => _stage = _Stage.downloading);
        await _translator.downloadModels(source.language);
        if (!mounted) return;
      }

      setState(() => _stage = _Stage.translating);
      final out = await _translator.translateAll(
        source.language,
        [for (final b in blocks) b.text],
      );
      if (!mounted) return;

      final pairs = [
        for (var i = 0; i < blocks.length; i++)
          _Pair(blocks[i].text, out[i], blocks[i].box),
      ];
      _scan.stop();
      setState(() {
        _pairs = pairs;
        _stage = _Stage.done;
      });
      HapticFeedback.lightImpact();

      await _history.add(
        userId: userId,
        sourceLabel: source.label,
        original: pairs.map((p) => p.original).join('\n'),
        translated: pairs.map((p) => p.translated).join('\n'),
      );
    } on ModelDownloadException {
      _fail('Model bahasa belum terunduh. Sambungkan internet lalu coba lagi.');
    } catch (_) {
      _fail('Foto tidak bisa diproses. Coba ambil ulang.');
    }
  }

  void _fail(String text) {
    if (!mounted) return;
    _scan.stop();
    setState(() {
      _stage = _Stage.error;
      _message = text;
    });
  }

  void _chooseLanguage(SourceLanguage l) {
    if (_busy || l == _source) return;
    HapticFeedback.selectionClick();
    setState(() => _source = l);
    // Bahasa yang salah dipilih itu umum, jadi foto yang sama langsung diterjemahkan ulang.
    final path = _photoPath;
    if (path != null) _process(path);
  }

  Future<void> _copy(String text, String done) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    HapticFeedback.selectionClick();
    _toast(done);
  }

  Future<void> _openHistory() async {
    HapticFeedback.selectionClick();
    await showTranslateHistorySheet(
      context,
      repo: _history,
      userId: _userId,
    );
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            _reveal(0, _header()),
            const SizedBox(height: 18),
            _reveal(
              1,
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _languageSelector(),
                  const SizedBox(height: 14),
                  _stageCard(),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _reveal(2, _actions()),
            const SizedBox(height: 22),
            if (_stage == _Stage.error) _errorCard(),
            if (_stage == _Stage.done) ..._results(),
          ],
        ),
      ),
    );
  }

  Widget _header() => Row(
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
                Text('Terjemah Kamera', style: AppTheme.heading(24)),
                const Text(
                  'Foto teks asing, baca artinya dalam bahasa Indonesia',
                  style: TextStyle(fontSize: 12.5, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          RoundIconButton(
            icon: Icons.history_rounded,
            label: 'Riwayat',
            onTap: _openHistory,
          ),
        ],
      );

  Widget _languageSelector() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bahasa pada foto',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final l in kSourceLanguages)
                _LangChip(
                  label: l.label,
                  selected: l == _source,
                  onTap: _busy ? null : () => _chooseLanguage(l),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Dipakai di ${_source.usedIn}.',
            style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
          ),
        ],
      );

  Widget _stageCard() {
    final path = _photoPath;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: path == null ? _emptyStage() : _photoStage(path),
      ),
    );
  }

  Widget _emptyStage() => Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 132,
              height: 104,
              child: CustomPaint(painter: ViewfinderPainter()),
            ),
            const SizedBox(height: 16),
            Text('Arahkan kamera ke teks', style: AppTheme.heading(17)),
            const SizedBox(height: 6),
            const Text(
              'Papan jalan, menu, atau label produk dalam huruf Latin. Aksara Thai, Khmer, Lao, dan Myanmar belum bisa dibaca.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.muted,
                height: 1.45,
              ),
            ),
          ],
        ),
      );

  Widget _photoStage(String path) {
    return LayoutBuilder(
      builder: (context, c) {
        final size = _photoSize;
        const maxH = 380.0;
        var w = c.maxWidth;
        var h = 240.0;
        if (size != null && size.width > 0 && size.height > 0) {
          final s = math.min(c.maxWidth / size.width, maxH / size.height);
          w = size.width * s;
          h = size.height * s;
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: AppColors.ink,
              alignment: Alignment.center,
              child: SizedBox(
                width: w,
                height: h,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(File(path), fit: BoxFit.fill),
                    if (size != null)
                      AnimatedBuilder(
                        animation: _scan,
                        builder: (_, __) => CustomPaint(
                          painter: ScanOverlayPainter(
                            imageSize: size,
                            boxes: [for (final p in _pairs) p.box],
                            selected: _selected,
                            scanning: _busy,
                            progress: _scan.value,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (_busy) _statusBar(),
          ],
        );
      },
    );
  }

  Widget _statusBar() {
    final text = switch (_stage) {
      _Stage.reading => 'Membaca teks pada foto',
      _Stage.downloading =>
        'Mengunduh model bahasa. Cukup sekali dan butuh internet',
      _Stage.translating => 'Menerjemahkan ke bahasa Indonesia',
      _ => '',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actions() => Row(
        children: [
          Expanded(
            child: _ActionButton(
              icon: Icons.photo_camera_rounded,
              label: 'Ambil foto',
              filled: true,
              onTap: _busy ? null : () => _pick(ImageSource.camera),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ActionButton(
              icon: Icons.photo_library_rounded,
              label: 'Dari galeri',
              filled: false,
              onTap: _busy ? null : () => _pick(ImageSource.gallery),
            ),
          ),
        ],
      );

  Widget _errorCard() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(
                Icons.info_outline_rounded,
                color: AppColors.error,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Belum berhasil', style: AppTheme.heading(15)),
                  const SizedBox(height: 4),
                  Text(
                    _message,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: AppColors.muted,
                      height: 1.45,
                    ),
                  ),
                  if (_photoPath != null) ...[
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: () => _process(_photoPath!),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 36),
                        foregroundColor: AppColors.ink,
                      ),
                      child: const Text(
                        'Coba lagi',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );

  List<Widget> _results() => [
        Row(
          children: [
            Text('Terjemahan', style: AppTheme.heading(18)),
            const Spacer(),
            Text(
              '${_pairs.length} bagian teks',
              style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < _pairs.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _PairTile(
              pair: _pairs[i],
              selected: _selected == i,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selected = _selected == i ? null : i);
              },
              onCopy: () => _copy(_pairs[i].translated, 'Terjemahan disalin'),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _copy(
              _pairs.map((p) => p.translated).join('\n'),
              'Semua terjemahan disalin',
            ),
            icon: const Icon(Icons.copy_all_rounded, size: 18),
            label: const Text(
              'Salin semua terjemahan',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            style: TextButton.styleFrom(foregroundColor: AppColors.ink),
          ),
        ),
      ];
}

class _LangChip extends StatelessWidget {
  const _LangChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Bahasa $label',
      child: Opacity(
        opacity: onTap == null && !selected ? .5 : 1,
        child: Material(
          color: selected ? AppColors.ink : Colors.white,
          shape: StadiumBorder(
            side: BorderSide(
              color: selected ? AppColors.ink : AppColors.border,
            ),
          ),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppColors.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fg = filled ? Colors.white : AppColors.ink;
    return Opacity(
      opacity: onTap == null ? .5 : 1,
      child: Material(
        color: filled ? AppColors.ink : Colors.white,
        shape: StadiumBorder(
          side: BorderSide(color: filled ? AppColors.ink : AppColors.border),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: SizedBox(
            height: 52,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: fg),
                const SizedBox(width: 8),
                Text(label, style: AppTheme.heading(14.5, color: fg)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PairTile extends StatelessWidget {
  const _PairTile({
    required this.pair,
    required this.selected,
    required this.onTap,
    required this.onCopy,
  });

  final _Pair pair;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? AppColors.teal : AppColors.border,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pair.original,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.muted,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      pair.translated,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Salin terjemahan',
                onPressed: onCopy,
                icon: const Icon(
                  Icons.copy_rounded,
                  size: 19,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

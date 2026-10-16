import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/round_icon_button.dart';
import '../auth/auth_repository.dart';
import '../explore/data/country_seed.dart';
import '../explore/models/country.dart';
import 'guide_models.dart';
import 'guide_repository.dart';

enum _Banner { none, offline, quota }

const _suggestions = [
  (Icons.restaurant_menu_rounded, 'Makanan wajib coba', 'Makanan apa saja yang wajib dicoba?', false),
  (Icons.map_outlined, 'Rencana 2 hari', 'Buatkan rencana perjalanan 2 hari yang singkat.', false),
  (Icons.groups_rounded, 'Etika dan budaya', 'Apa etika dan adat yang perlu kuketahui sebagai pengunjung?', false),
  (Icons.quiz_rounded, 'Latih aku dengan soal', 'Latih aku dengan soal', true),
];

/// Tanya Pemandu: chat dengan LLM (Gemini lewat server) seputar negara pilihan.
class GuidePage extends StatefulWidget {
  const GuidePage({super.key, this.initialCountry});

  final String? initialCountry;

  static Route<void> route({String? initialCountry}) => PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 380),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (_, __, ___) => GuidePage(initialCountry: initialCountry),
        transitionsBuilder: (_, anim, __, child) {
          final c = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: c,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, .06), end: Offset.zero).animate(c),
              child: child,
            ),
          );
        },
      );

  @override
  State<GuidePage> createState() => _GuidePageState();
}

class _GuidePageState extends State<GuidePage> with SingleTickerProviderStateMixin {
  late final GuideRepository _repo = GuideRepository(context.read<AuthRepository>());
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  final _input = TextEditingController();
  final _scroll = ScrollController();

  late String _code = widget.initialCountry ?? 'MY';
  final List<GuideMessage> _msgs = [];
  bool _busy = false;
  bool _loading = true;
  int? _remaining;
  _Banner _banner = _Banner.none;
  String? _pending;
  bool _pendingQuiz = false;

  String get _userId => context.read<AuthRepository>().currentUser?.id ?? 'guest';

  Country get _country => CountrySeed.all.firstWhere(
        (c) => c.code == _code,
        orElse: () => CountrySeed.all.first,
      );

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _pulse.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final hist = await _repo.loadHistory(_userId, _code);
    final q = await _repo.quota();
    if (!mounted) return;
    setState(() {
      _msgs
        ..clear()
        ..addAll(hist);
      _remaining = q;
      _loading = false;
      if (q == 0) _banner = _Banner.quota;
    });
    _scrollEnd(jump: true);
  }

  void _scrollEnd({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final end = _scroll.position.maxScrollExtent;
      if (jump) {
        _scroll.jumpTo(end);
      } else {
        _scroll.animateTo(end,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  bool get _canSend => !_busy && (_remaining == null || _remaining! > 0);

  Future<void> _send(String raw, {bool quiz = false}) async {
    final text = raw.trim();
    if (text.isEmpty || _busy) return;
    if (_remaining != null && _remaining! <= 0) {
      setState(() => _banner = _Banner.quota);
      return;
    }
    HapticFeedback.selectionClick();
    final userMsg = GuideMessage(role: GuideRole.user, text: text);
    final history = List<GuideMessage>.of(_msgs);
    setState(() {
      _msgs.removeWhere((m) => m.isError);
      _msgs.add(userMsg);
      _busy = true;
      _banner = _Banner.none;
      _pending = null;
      _input.clear();
    });
    _scrollEnd();

    try {
      GuideMessage reply;
      int remaining;
      if (quiz) {
        final r = await _repo.quiz(_code);
        remaining = r.remaining;
        reply = GuideMessage(
          role: GuideRole.guide,
          text: 'Soal latihan',
          quiz: r.quiz,
        );
      } else {
        final r = await _repo.ask(countryCode: _code, message: text, history: history);
        remaining = r.remaining;
        reply = GuideMessage(role: GuideRole.guide, text: r.reply, animate: true);
        await _repo.save(_userId, _code, userMsg);
        await _repo.save(_userId, _code, reply);
      }
      if (!mounted) return;
      setState(() {
        _msgs.add(reply);
        _remaining = remaining;
        _busy = false;
        if (remaining == 0) _banner = _Banner.quota;
      });
    } on GuideException catch (e) {
      if (!mounted) return;
      setState(() {
        _msgs.remove(userMsg);
        _busy = false;
        _input.text = text; // kembalikan teks agar tidak perlu mengetik ulang
        switch (e.kind) {
          case GuideErrorKind.network:
            _banner = _Banner.offline;
            _pending = text;
            _pendingQuiz = quiz;
          case GuideErrorKind.quota:
            _banner = _Banner.quota;
            _remaining = 0;
          case GuideErrorKind.other:
            _msgs.add(GuideMessage(role: GuideRole.guide, text: e.message, isError: true));
        }
      });
    }
    _scrollEnd();
  }

  Future<void> _switchCountry(String code) async {
    if (code == _code) return;
    HapticFeedback.selectionClick();
    setState(() {
      _code = code;
      _loading = true;
      _banner = _remaining == 0 ? _Banner.quota : _Banner.none;
    });
    await _init();
  }

  Future<void> _pickCountry() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * .7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(3)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Bahas negara mana?', style: AppTheme.heading(18)),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  children: [
                    for (final c in CountrySeed.all)
                      ListTile(
                        leading: Container(
                          width: 42,
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: c.code == _code ? AppColors.teal : AppColors.sea,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(c.code,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: c.code == _code ? Colors.white : AppColors.deepNavy,
                              )),
                        ),
                        title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(c.capital),
                        trailing: c.code == _code
                            ? const Icon(Icons.check_rounded, color: AppColors.teal)
                            : null,
                        onTap: () => Navigator.pop(ctx, c.code),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) _switchCountry(picked);
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Hapus percakapan?'),
        content: Text('Riwayat chat tentang ${_country.name} di perangkat ini akan dihapus.'),
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
    await _repo.clear(_userId, _code);
    if (mounted) setState(_msgs.clear);
  }

  // ---------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => FocusScope.of(context).unfocus(),
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : (_msgs.isEmpty && !_busy ? _hello() : _list()),
              ),
            ),
            if (_banner == _Banner.offline) _offlineBanner(),
            if (_banner == _Banner.quota) _quotaBanner(),
            _composer(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: AppColors.ink.withOpacity(.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              RoundIconButton(
                icon: Icons.arrow_back_rounded,
                label: 'Kembali',
                size: 42,
                elevated: false,
                onTap: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: 10),
              _Avatar(size: 40, pulse: _busy ? _pulse : null),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pemandu WanderGeo',
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.heading(15.5)),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _banner == _Banner.offline ? AppColors.error : AppColors.success,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(_banner == _Banner.offline ? 'Offline' : 'Didukung AI',
                            style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Menu',
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (v) {
                  if (v == 'clear') _confirmClear();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'clear', child: Text('Hapus percakapan')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _countryBar(),
          ),
        ],
      ),
    );
  }

  /// Pemilih negara: baris tersendiri di bawah judul agar tidak berebut ruang
  /// dengan nama "Pemandu WanderGeo".
  Widget _countryBar() {
    final c = _country;
    return Material(
      color: AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _pickCountry,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.teal,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(c.code,
                    style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Negara yang dibahas',
                        style: TextStyle(fontSize: 10.5, color: AppColors.muted)),
                    Text(c.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  ],
                ),
              ),
              const Text('Ganti',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.teal)),
              const Icon(Icons.expand_more_rounded, size: 20, color: AppColors.teal),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hello() {
    final c = _country;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Column(
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                _Rings(pulse: _pulse),
                const _Avatar(size: 80),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text('Halo, aku Pemandu!', style: AppTheme.heading(22)),
          const SizedBox(height: 6),
          Text(
            'Aku bisa bantu seputar ${c.name}: kuliner, rencana perjalanan, adat, sampai latihan soal. Mau mulai dari mana?',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, height: 1.5),
          ),
          const SizedBox(height: 18),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.45,
            children: [
              for (final s in _suggestions)
                Material(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: _canSend ? () => _send(s.$3, quiz: s.$4) : null,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: AppColors.sea,
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Icon(s.$1, size: 19, color: AppColors.teal),
                          ),
                          const Spacer(),
                          Text(s.$2,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, height: 1.25)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _list() {
    final last = _msgs.isEmpty ? null : _msgs.last;
    final showFollowUps = !_busy &&
        last != null &&
        last.role == GuideRole.guide &&
        !last.isError &&
        !last.animate;
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      children: [
        for (final m in _msgs)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: m.role == GuideRole.user
                ? _UserBubble(text: m.text)
                : _GuideBubble(message: m, onProgress: _scrollEnd, onDone: () {
                    if (mounted) setState(() => m.animate = false);
                  }),
          ),
        if (_busy)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Avatar(size: 30),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: _guideBubbleDecoration,
                  child: _TypingDots(pulse: _pulse),
                ),
              ],
            ),
          ),
        if (showFollowUps) _followUps(),
      ],
    );
  }

  Widget _followUps() {
    final start = _msgs.length % _suggestions.length;
    final picks = [
      for (var i = 0; i < 3; i++) _suggestions[(start + i) % _suggestions.length],
    ];
    return Padding(
      padding: const EdgeInsets.only(left: 38, bottom: 6),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final s in picks)
            ActionChip(
              label: Text(s.$2),
              onPressed: _canSend ? () => _send(s.$3, quiz: s.$4) : null,
              backgroundColor: Colors.white,
              side: const BorderSide(color: AppColors.teal, width: 1.4),
              labelStyle: const TextStyle(color: AppColors.teal, fontWeight: FontWeight.w700, fontSize: 13),
              shape: const StadiumBorder(),
            ),
        ],
      ),
    );
  }

  Widget _offlineBanner() => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFCECEA),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.wifi_off_rounded, color: AppColors.error),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Tidak ada koneksi. Pemandu butuh internet.',
                  style: TextStyle(fontSize: 13, height: 1.3, color: Color(0xFF8A2A22))),
            ),
            TextButton(
              onPressed: _pending == null ? null : () => _send(_pending!, quiz: _pendingQuiz),
              child: const Text('Coba lagi'),
            ),
          ],
        ),
      );

  Widget _quotaBanner() => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFBEFD0),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          children: [
            Icon(Icons.schedule_rounded, color: AppColors.goldDark),
            SizedBox(width: 10),
            Expanded(
              child: Text('Kuota pertanyaan hari ini sudah habis. Kembali lagi besok ya.',
                  style: TextStyle(fontSize: 13, height: 1.3, color: Color(0xFF7A5500))),
            ),
          ],
        ),
      );

  Widget _composer() {
    final left = _remaining;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: AppColors.ink.withOpacity(.05), blurRadius: 14, offset: const Offset(0, -4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    left == null
                        ? 'Dijawab AI, bisa keliru. Jangan tulis data pribadi.'
                        : 'Sisa $left dari 10 pertanyaan hari ini · Dijawab AI, bisa keliru',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                  ),
                ),
                if (left != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: SizedBox(
                      width: 60,
                      height: 5,
                      child: LinearProgressIndicator(
                        value: (left / 10).clamp(0, 1).toDouble(),
                        backgroundColor: AppColors.border,
                        color: AppColors.teal,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  enabled: _canSend,
                  maxLength: 500,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (v) => _send(v, quiz: _isQuizRequest(v)),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: 'Tanya tentang ${_country.name}…',
                    hintStyle: const TextStyle(color: AppColors.hint, fontSize: 14.5),
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(26),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(26),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(26),
                      borderSide: const BorderSide(color: AppColors.teal, width: 1.6),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: _canSend ? AppColors.gold : AppColors.border,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _canSend ? () => _send(_input.text, quiz: _isQuizRequest(_input.text)) : null,
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: _busy
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.ink),
                          )
                        : Icon(Icons.arrow_upward_rounded,
                            color: _canSend ? AppColors.ink : AppColors.hint),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _isQuizRequest(String t) => RegExp(r'\b(soal|latih|kuis|quiz)\b', caseSensitive: false).hasMatch(t);
}

final _guideBubbleDecoration = BoxDecoration(
  color: Colors.white,
  borderRadius: const BorderRadius.only(
    topLeft: Radius.circular(20),
    topRight: Radius.circular(20),
    bottomRight: Radius.circular(20),
    bottomLeft: Radius.circular(6),
  ),
  border: Border.all(color: AppColors.border),
);

// ---------------------------------------------------------------------------

class _Avatar extends StatelessWidget {
  const _Avatar({required this.size, this.pulse});

  final double size;
  final Animation<double>? pulse;

  @override
  Widget build(BuildContext context) {
    final core = Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(color: AppColors.deepNavy, shape: BoxShape.circle),
      child: Icon(Icons.auto_awesome_rounded, size: size * .48, color: AppColors.gold),
    );
    if (pulse == null) return core;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          AnimatedBuilder(
            animation: pulse!,
            builder: (_, __) => Container(
              width: size * (1 + .35 * pulse!.value),
              height: size * (1 + .35 * pulse!.value),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.teal.withOpacity(1 - pulse!.value), width: 2),
              ),
            ),
          ),
          core,
        ],
      ),
    );
  }
}

class _Rings extends StatelessWidget {
  const _Rings({required this.pulse});

  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (_, __) => Stack(
        alignment: Alignment.center,
        children: [
          for (final phase in const [0.0, .5])
            Builder(builder: (_) {
              final t = (pulse.value + phase) % 1.0;
              return Container(
                width: 80 + 40 * t,
                height: 80 + 40 * t,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.teal.withOpacity((1 - t) * .6), width: 2),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _TypingDots extends StatelessWidget {
  const _TypingDots({required this.pulse});

  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Container(
              width: 8,
              height: 8,
              margin: EdgeInsets.only(right: i < 2 ? 5 : 0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.hint.withOpacity(.35 + .65 * (.5 + .5 * math.sin((pulse.value * 2 - i * .3) * math.pi * 2))),
              ),
            ),
        ],
      ),
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .78),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: const BoxDecoration(
            color: AppColors.ink,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(6),
            ),
          ),
          child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 14.5, height: 1.45)),
        ),
      ),
    );
  }
}

class _GuideBubble extends StatelessWidget {
  const _GuideBubble({required this.message, required this.onProgress, required this.onDone});

  final GuideMessage message;
  final VoidCallback onProgress;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final Widget body;
    if (message.quiz != null) {
      body = _QuizCard(message: message);
    } else if (message.isError) {
      body = Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: const Color(0xFFFCECEA),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message.text,
                  style: const TextStyle(color: Color(0xFF8A2A22), fontSize: 13.5, height: 1.4)),
            ),
          ],
        ),
      );
    } else {
      body = Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: _guideBubbleDecoration,
        child: _RevealText(
          text: message.text,
          animate: message.animate,
          onProgress: onProgress,
          onDone: onDone,
        ),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Avatar(size: 30),
        const SizedBox(width: 8),
        Expanded(child: body),
      ],
    );
  }
}

/// Menampilkan teks balasan kata demi kata (efek mengetik), lalu format penuh.
class _RevealText extends StatefulWidget {
  const _RevealText({
    required this.text,
    required this.animate,
    required this.onProgress,
    required this.onDone,
  });

  final String text;
  final bool animate;
  final VoidCallback onProgress;
  final VoidCallback onDone;

  @override
  State<_RevealText> createState() => _RevealTextState();
}

class _RevealTextState extends State<_RevealText> with SingleTickerProviderStateMixin {
  AnimationController? _c;
  late final List<String> _words = widget.text.split(' ');

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      final ms = (_words.length * 22).clamp(300, 3500).toInt();
      _c = AnimationController(vsync: this, duration: Duration(milliseconds: ms))
        ..addListener(widget.onProgress)
        ..forward().whenComplete(() {
          if (mounted) widget.onDone();
        });
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (!widget.animate || c == null) return GuideRichText(widget.text);
    return AnimatedBuilder(
      animation: c,
      builder: (_, __) {
        final n = (c.value * _words.length).ceil().clamp(1, _words.length).toInt();
        var s = _words.take(n).join(' ');
        // Hindari tanda ** yang belum berpasangan saat teks baru setengah tampil.
        if ('**'.allMatches(s).length.isOdd) s = s.substring(0, s.lastIndexOf('**'));
        return GuideRichText(s);
      },
    );
  }
}

/// Format sederhana: **tebal**, daftar berpoin (-, *, •) dan daftar bernomor.
class GuideRichText extends StatelessWidget {
  const GuideRichText(this.text, {super.key});

  final String text;

  static final _bold = RegExp(r'\*\*(.+?)\*\*');
  static final _bullet = RegExp(r'^[-*•]\s+');
  static final _number = RegExp(r'^(\d+)[.)]\s+');

  static const _base = TextStyle(fontSize: 14.5, height: 1.5, color: AppColors.ink);

  InlineSpan _inline(String line) {
    final spans = <InlineSpan>[];
    var i = 0;
    for (final m in _bold.allMatches(line)) {
      if (m.start > i) spans.add(TextSpan(text: line.substring(i, m.start)));
      spans.add(TextSpan(text: m.group(1), style: const TextStyle(fontWeight: FontWeight.w700)));
      i = m.end;
    }
    if (i < line.length) spans.add(TextSpan(text: line.substring(i)));
    return TextSpan(style: _base, children: spans);
  }

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (final raw in text.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) {
        rows.add(const SizedBox(height: 6));
        continue;
      }
      final clean = line.replaceFirst(RegExp(r'^#+\s*'), '');
      final isBullet = !clean.startsWith('**') && _bullet.hasMatch(clean);
      final numMatch = _number.firstMatch(clean);
      if (isBullet || numMatch != null) {
        final marker = isBullet ? '•' : '${numMatch!.group(1)}.';
        final body = clean.replaceFirst(isBullet ? _bullet : _number, '');
        rows.add(Padding(
          padding: const EdgeInsets.only(top: 3, left: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 18, child: Text(marker, style: _base)),
              Expanded(child: Text.rich(_inline(body))),
            ],
          ),
        ));
      } else {
        rows.add(Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text.rich(_inline(clean)),
        ));
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }
}

class _QuizCard extends StatefulWidget {
  const _QuizCard({required this.message});

  final GuideMessage message;

  @override
  State<_QuizCard> createState() => _QuizCardState();
}

class _QuizCardState extends State<_QuizCard> {
  @override
  Widget build(BuildContext context) {
    final q = widget.message.quiz!;
    final picked = widget.message.picked;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _guideBubbleDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.quiz_rounded, size: 18, color: AppColors.teal),
              const SizedBox(width: 6),
              Text('Soal latihan', style: AppTheme.heading(13.5)),
            ],
          ),
          const SizedBox(height: 8),
          Text(q.question, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, height: 1.4)),
          const SizedBox(height: 4),
          for (var i = 0; i < q.options.length; i++) _option(q, i, picked),
          if (picked != null) ...[
            const SizedBox(height: 10),
            Text(
              '${picked == q.correct ? 'Benar! ' : 'Kurang tepat. '}${q.explanation}',
              style: const TextStyle(fontSize: 13, height: 1.45, color: AppColors.muted),
            ),
            const SizedBox(height: 4),
            const Text('Soal dibuat AI, cek ulang jika ragu.',
                style: TextStyle(fontSize: 11, color: AppColors.hint)),
          ],
        ],
      ),
    );
  }

  Widget _option(GuideQuiz q, int i, int? picked) {
    final answered = picked != null;
    final good = answered && i == q.correct;
    final bad = answered && i == picked && i != q.correct;
    final color = good ? AppColors.success : (bad ? AppColors.error : AppColors.border);
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Opacity(
        opacity: answered && !good && !bad ? .5 : 1,
        child: Material(
          color: good
              ? const Color(0xFFE8F6EF)
              : bad
                  ? const Color(0xFFFCECEA)
                  : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: color, width: 1.8),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: answered
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    setState(() => widget.message.picked = i);
                  },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: good || bad ? color : AppColors.background,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: good || bad
                        ? Icon(good ? Icons.check_rounded : Icons.close_rounded, size: 16, color: Colors.white)
                        : Text('ABCD'[i], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(q.options[i], style: const TextStyle(fontSize: 14))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

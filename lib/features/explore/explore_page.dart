import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/services/compass_service.dart';
import '../../core/services/location_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/geo_utils.dart';
import '../../core/widgets/round_icon_button.dart';
import 'data/country_seed.dart';
import 'logic/recommender.dart';
import 'models/country.dart';
import 'widgets/country_sheet.dart';
import 'widgets/country_tile.dart';
import 'widgets/world_map_card.dart';

enum SortMode { distance, name, difficulty }

/// Halaman Eksplorasi: pencarian + filter, peta interaktif (LBS + kompas),
/// dan daftar negara terurut jarak dengan rekomendasi AI.
class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage>
    with SingleTickerProviderStateMixin {
  static final _fieldBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(24),
    borderSide: const BorderSide(color: AppColors.border),
  );

  final _search = TextEditingController();
  final _location = LocationService();
  late final Stream<double?> _headings = CompassService().headings;

  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  )..forward();

  /// Animasi muncul bertahap: header, cari, chip, peta, judul, daftar.
  late final List<Animation<double>> _stag = List.generate(6, (i) {
    final start = i * .09;
    return CurvedAnimation(
      parent: _enter,
      curve: Interval(start, start + .4, curve: Curves.easeOutCubic),
    );
  });

  final List<Country> _countries = List.of(CountrySeed.all);
  final int _coins = 120; // contoh; nanti dari Supabase

  CountryRegion _region = CountryRegion.asean;
  CountryStatus? _status;
  SortMode _sort = SortMode.distance;
  String _query = '';
  String? _selected;
  UserLocation? _user;

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  @override
  void dispose() {
    _enter.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadLocation() async {
    final u = await _location.current();
    if (mounted) setState(() => _user = u);
  }

  // ---------- data turunan ----------

  List<Country> get _pool =>
      _countries.where((c) => c.region == _region).toList();

  double? _distance(Country c) => _user == null
      ? null
      : GeoUtils.haversineKm(_user!.lat, _user!.lng, c.lat, c.lng);

  List<Country> _matches(Country? recommended) {
    final q = _query.trim().toLowerCase();
    final list = _pool.where((c) {
      if (_status != null && c.status != _status) return false;
      if (q.isEmpty) return true;
      return c.name.toLowerCase().contains(q) ||
          c.capital.toLowerCase().contains(q) ||
          c.code.toLowerCase().contains(q);
    }).toList();

    switch (_sort) {
      case SortMode.distance:
        if (_user != null) {
          list.sort((a, b) => _distance(a)!.compareTo(_distance(b)!));
        }
      case SortMode.name:
        list.sort((a, b) => a.name.compareTo(b.name));
      case SortMode.difficulty:
        list.sort((a, b) => a.difficulty.compareTo(b.difficulty));
    }
    if (recommended != null && q.isEmpty) {
      final i = list.indexWhere((c) => c.code == recommended.code);
      if (i > 0) list.insert(0, list.removeAt(i));
    }
    return list;
  }

  // ---------- aksi ----------

  void _soon(String what) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('$what segera hadir'),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        backgroundColor: AppColors.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ));
  }

  Future<void> _onSelect(Country c) async {
    HapticFeedback.selectionClick();
    setState(() => _selected = c.code);
    await CountrySheet.show(
      context,
      country: c,
      distanceKm: _distance(c),
      approximateLocation: _user?.approximate ?? true,
      onStart: () => _soon('Misi ${c.name}'),
    );
    if (mounted) setState(() => _selected = null);
  }

  Future<void> _openSort() async {
    const labels = {
      SortMode.distance: 'Terdekat dari kamu',
      SortMode.name: 'Nama A–Z',
      SortMode.difficulty: 'Tingkat kesulitan (mudah dulu)',
    };
    final picked = await showModalBottomSheet<SortMode>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text('Urutkan negara', style: AppTheme.heading(18)),
              const SizedBox(height: 6),
              for (final m in SortMode.values)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(labels[m]!,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  trailing: m == _sort
                      ? const Icon(Icons.check_rounded, color: AppColors.teal)
                      : null,
                  onTap: () => Navigator.pop(ctx, m),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) setState(() => _sort = picked);
  }

  // ---------- tampilan ----------

  Widget _reveal(int i, Widget child) => FadeTransition(
        opacity: _stag[i],
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, .12), end: Offset.zero)
              .animate(_stag[i]),
          child: child,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final pool = _pool;
    final recommended = recommendNext(pool, _user);
    final items = _matches(recommended);
    final done = _countries.where((c) => c.status == CountryStatus.selesai).length;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(20, 12, 20, 120 + bottomInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _reveal(0, _header(done)),
              const SizedBox(height: 16),
              _reveal(1, _searchRow()),
              const SizedBox(height: 12),
              _reveal(2, _chips(pool)),
              const SizedBox(height: 14),
              _reveal(
                3,
                WorldMapCard(
                  region: _region,
                  countries: pool,
                  matchingCodes: items.map((c) => c.code).toSet(),
                  selectedCode: _selected,
                  userLocation: _user,
                  headings: _headings,
                  onRegionChanged: (r) {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _region = r;
                      _selected = null;
                    });
                  },
                  onSelect: _onSelect,
                ),
              ),
              const SizedBox(height: 22),
              _reveal(4, _sectionTitle()),
              const SizedBox(height: 10),
              _reveal(5, _list(items, recommended)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(int done) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Eksplorasi', style: AppTheme.heading(26)),
              const SizedBox(height: 2),
              Text(
                '$done dari ${_countries.length} negara selesai',
                style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
              ),
            ],
          ),
        ),
        RoundIconButton(
          icon: Icons.currency_exchange_rounded,
          label: 'Alat Perjalanan',
          onTap: () => _soon('Alat Perjalanan'),
        ),
        const SizedBox(width: 8),
        RoundIconButton(
          icon: Icons.auto_awesome_rounded,
          label: 'Tanya Pemandu',
          onTap: () => _soon('Tanya Pemandu'),
        ),
        const SizedBox(width: 8),
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.monetization_on_rounded,
                  size: 20, color: AppColors.gold),
              const SizedBox(width: 5),
              Text(
                '$_coins',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.goldDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _searchRow() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _search,
            onChanged: (v) => setState(() => _query = v),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Cari negara atau ibukota',
              hintStyle:
                  const TextStyle(color: AppColors.hint, fontSize: 14),
              prefixIcon:
                  const Icon(Icons.search_rounded, color: AppColors.muted),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Hapus',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _search.clear();
                        setState(() => _query = '');
                      },
                    ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: _fieldBorder,
              enabledBorder: _fieldBorder,
              focusedBorder: _fieldBorder.copyWith(
                borderSide:
                    const BorderSide(color: AppColors.teal, width: 1.6),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        RoundIconButton(
          icon: Icons.tune_rounded,
          label: 'Urutkan',
          size: 48,
          onTap: _openSort,
        ),
      ],
    );
  }

  Widget _chips(List<Country> pool) {
    int n(CountryStatus? s) =>
        s == null ? pool.length : pool.where((c) => c.status == s).length;
    final defs = <(String, CountryStatus?)>[
      ('Semua', null),
      ('Terbuka', CountryStatus.terbuka),
      ('Selesai', CountryStatus.selesai),
      ('Terkunci', CountryStatus.terkunci),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (final d in defs)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _FilterPill(
                label: '${d.$1} · ${n(d.$2)}',
                selected: _status == d.$2,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _status = d.$2);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionTitle() {
    final near = _sort == SortMode.distance && _user != null;
    return Row(
      children: [
        Text(near ? 'Dekat kamu' : 'Daftar negara',
            style: AppTheme.heading(17)),
        const Spacer(),
        if (_user?.approximate == true)
          const Row(
            children: [
              Icon(Icons.location_searching_rounded,
                  size: 14, color: AppColors.hint),
              SizedBox(width: 4),
              Text('Lokasi perkiraan',
                  style: TextStyle(fontSize: 12, color: AppColors.hint)),
            ],
          ),
      ],
    );
  }

  Widget _list(List<Country> items, Country? recommended) {
    final key = ValueKey(
      '${_region.name}|${_status?.name}|${_sort.name}|${_query.trim()}|${_user != null}',
    );
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.topCenter,
          children: [...previous, if (current != null) current],
        ),
        child: items.isEmpty
            ? _EmptyState(key: key)
            : Column(
                key: key,
                children: [
                  for (final c in items)
                    CountryTile(
                      country: c,
                      distanceKm: _distance(c),
                      recommended:
                          recommended?.code == c.code && _query.trim().isEmpty,
                      onTap: () => _onSelect(c),
                    ),
                ],
              ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.ink : Colors.white,
            borderRadius: BorderRadius.circular(19),
            border: Border.all(
              color: selected ? AppColors.ink : AppColors.border,
            ),
          ),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 220),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppColors.deepNavy,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          Icon(Icons.travel_explore_rounded, size: 44, color: AppColors.hint),
          SizedBox(height: 10),
          Text('Tidak ada negara yang cocok',
              style: TextStyle(fontWeight: FontWeight.w700)),
          SizedBox(height: 2),
          Text('Coba kata kunci atau filter lain.',
              style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
        ],
      ),
    );
  }
}

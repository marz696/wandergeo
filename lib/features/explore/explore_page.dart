import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/services/compass_service.dart';
import '../../core/services/location_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/geo_utils.dart';
import '../../core/widgets/round_icon_button.dart';
import 'data/country_seed.dart';
import 'logic/recommender.dart';
import 'models/country.dart';
import 'widgets/country_card.dart';
import 'widgets/country_detail_panel.dart';
import 'widgets/country_pin.dart';
import 'widgets/map_controls.dart';
import 'widgets/region_toggle.dart';

enum SortMode { distance, name, difficulty }

/// Eksplorasi: peta penuh layar (flutter_map + OpenStreetMap), header,
/// pencarian + filter, carousel negara, dan panel detail.
class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage>
    with TickerProviderStateMixin {
  static final _aseanBounds = LatLngBounds(
    const LatLng(-10.5, 94),
    const LatLng(24, 126.5),
  );
  static final _ukBounds = LatLngBounds(
    const LatLng(49.5, -10.5),
    const LatLng(59.5, 2.5),
  );

  static final _fieldBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(26),
    borderSide: BorderSide.none,
  );

  final _map = MapController();
  final _search = TextEditingController();
  final _location = LocationService();
  late final Stream<double?> _headings = CompassService().headings;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  late final AnimationController _cam = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  VoidCallback? _camListener;

  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..forward();

  /// Animasi muncul bertahap: header, pencarian, chip.
  late final List<Animation<double>> _stag = List.generate(3, (i) {
    final start = i * .14;
    return CurvedAnimation(
      parent: _enter,
      curve: Interval(start, start + .5, curve: Curves.easeOutCubic),
    );
  });

  PageController _pages = PageController(viewportFraction: .82);

  final List<Country> _countries = List.of(CountrySeed.all);
  final int _coins = 120; // contoh; nanti dari Supabase

  CountryRegion _region = CountryRegion.asean;
  CountryStatus? _status;
  SortMode _sort = SortMode.distance;
  String _query = '';
  String? _selected;
  bool _sheetOpen = false;
  UserLocation? _user;
  EdgeInsets _fitPad = const EdgeInsets.fromLTRB(24, 240, 24, 260);

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  @override
  void dispose() {
    _enter.dispose();
    _pulse.dispose();
    _cam.dispose();
    _search.dispose();
    _pages.dispose();
    _map.dispose();
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

  // ---------- kamera peta ----------

  void _animateTo(LatLng center, double zoom) {
    final LatLng c0;
    final double z0;
    try {
      c0 = _map.camera.center;
      z0 = _map.camera.zoom;
    } catch (_) {
      return; // peta belum siap
    }
    if (_camListener != null) _cam.removeListener(_camListener!);
    _camListener = () {
      final t = Curves.easeInOutCubic.transform(_cam.value);
      _map.move(
        LatLng(
          c0.latitude + (center.latitude - c0.latitude) * t,
          c0.longitude + (center.longitude - c0.longitude) * t,
        ),
        z0 + (zoom - z0) * t,
      );
    };
    _cam.addListener(_camListener!);
    _cam.forward(from: 0);
  }

  void _fitRegion(CountryRegion r) {
    try {
      final cam = CameraFit.bounds(
        bounds: r == CountryRegion.asean ? _aseanBounds : _ukBounds,
        padding: _fitPad,
      ).fit(_map.camera);
      _animateTo(cam.center, cam.zoom);
    } catch (_) {}
  }

  void _flyToCountry(Country c, {required bool forSheet}) {
    const zoom = 5.2;
    // Geser pusat ke selatan agar pin berada di atas panel/carousel.
    final shiftPx = forSheet ? 150.0 : 70.0;
    final degPerPx = 360 / (256 * math.pow(2, zoom));
    final lat = c.lat - shiftPx * degPerPx * math.cos(c.lat * math.pi / 180);
    _animateTo(LatLng(lat, c.lng), zoom);
  }

  void _zoomBy(double delta) {
    try {
      final cam = _map.camera;
      _animateTo(cam.center, (cam.zoom + delta).clamp(2.5, 12.0).toDouble());
    } catch (_) {}
  }

  Future<void> _goToMe() async {
    HapticFeedback.selectionClick();
    final u = await _location.current();
    if (!mounted) return;
    setState(() => _user = u);
    _animateTo(LatLng(u.lat, u.lng), 6);
  }

  // ---------- aksi ----------

  void _soon(String what) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('$what segera hadir'),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 110),
        backgroundColor: AppColors.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ));
  }

  void _rebuildPages(int initial) {
    final old = _pages;
    _pages = PageController(viewportFraction: .82, initialPage: initial);
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  void _filtersChanged(VoidCallback change) {
    setState(() {
      change();
      _selected = null;
      _sheetOpen = false;
    });
    _rebuildPages(0);
  }

  void _focus(Country c, {required bool sheet}) {
    HapticFeedback.selectionClick();
    setState(() {
      _selected = c.code;
      _sheetOpen = sheet;
    });
    _flyToCountry(c, forSheet: sheet);
  }

  void _closeSheet() {
    final items = _matches(recommendNext(_pool, _user));
    final i = items.indexWhere((c) => c.code == _selected);
    setState(() => _sheetOpen = false);
    _rebuildPages(i < 0 ? 0 : i);
  }

  void _clearSelection() {
    if (_selected == null && !_sheetOpen) return;
    final wasOpen = _sheetOpen;
    setState(() {
      _selected = null;
      _sheetOpen = false;
    });
    if (wasOpen) _rebuildPages(0);
  }

  void _setRegion(CountryRegion r) {
    if (r == _region) return;
    HapticFeedback.selectionClick();
    _filtersChanged(() => _region = r);
    _fitRegion(r);
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
    if (picked != null) _filtersChanged(() => _sort = picked);
  }

  // ---------- tampilan ----------

  Widget _reveal(int i, Widget child) => FadeTransition(
        opacity: _stag[i],
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, .15), end: Offset.zero)
              .animate(_stag[i]),
          child: child,
        ),
      );

  List<LatLng> _routePoints(UserLocation u, Country c) {
    final dx = c.lng - u.lng;
    final dy = c.lat - u.lat;
    final cLat = (u.lat + c.lat) / 2 + dx * .22;
    final cLng = (u.lng + c.lng) / 2 - dy * .22;
    LatLng at(double t) {
      final a = (1 - t) * (1 - t);
      final b = 2 * (1 - t) * t;
      final d = t * t;
      return LatLng(
        a * u.lat + b * cLat + d * c.lat,
        a * u.lng + b * cLng + d * c.lng,
      );
    }

    return [for (var i = 0; i <= 32; i++) at(i / 32)];
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final safeTop = mq.padding.top;
    final navSpace = 92 + mq.padding.bottom;
    _fitPad = EdgeInsets.fromLTRB(24, safeTop + 210, 24, navSpace + 150);

    final pool = _pool;
    final recommended = recommendNext(pool, _user);
    final items = _matches(recommended);
    final matching = items.map((c) => c.code).toSet();
    final selected = _selected == null
        ? null
        : _countries.firstWhere((c) => c.code == _selected);
    final showRoute = selected != null &&
        _user != null &&
        selected.region == CountryRegion.asean &&
        _region == CountryRegion.asean;

    // Pin terpilih digambar paling akhir (di atas).
    final ordered = [
      ...pool.where((c) => c.code != _selected),
      ...pool.where((c) => c.code == _selected),
    ];

    final Widget panel;
    if (_sheetOpen && selected != null) {
      panel = CountryDetailPanel(
        key: ValueKey('detail-${selected.code}'),
        country: selected,
        distanceKm: _distance(selected),
        approximate: _user?.approximate ?? true,
        onStart: () => _soon('Misi ${selected.name}'),
        onTools: () => _soon('Alat Perjalanan'),
        onClose: _closeSheet,
      );
    } else if (items.isEmpty) {
      panel = const _EmptyCard(key: ValueKey('empty'));
    } else {
      panel = SizedBox(
        key: const ValueKey('carousel'),
        height: 116,
        child: PageView.builder(
          key: ObjectKey(_pages),
          controller: _pages,
          itemCount: items.length,
          onPageChanged: (i) {
            if (items[i].code != _selected) _focus(items[i], sheet: false);
          },
          itemBuilder: (_, i) {
            final c = items[i];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: CountryCard(
                country: c,
                distanceKm: _distance(c),
                recommended:
                    recommended?.code == c.code && _query.trim().isEmpty,
                highlighted: c.code == _selected,
                onTap: () => _focus(c, sheet: true),
              ),
            );
          },
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // ---- peta ----
          Positioned.fill(
            child: FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCameraFit:
                    CameraFit.bounds(bounds: _aseanBounds, padding: _fitPad),
                minZoom: 2.5,
                maxZoom: 12,
                backgroundColor: AppColors.sky,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
                onTap: (_, __) => _clearSelection(),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.wandergeo.app',
                  // Sedikit memudarkan tile agar pin lebih menonjol.
                  tileBuilder: (context, tile, image) => ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      Colors.white.withOpacity(.22),
                      BlendMode.srcATop,
                    ),
                    child: tile,
                  ),
                ),
                // Rute putus-putus digambar sebagai titik-titik kecil (CircleLayer)
                // agar tidak bergantung pada API garis yang berubah antar versi.
                if (showRoute)
                  CircleLayer(
                    circles: [
                      for (final p in _routePoints(_user!, selected!))
                        CircleMarker(
                          point: p,
                          radius: 3.2,
                          color: AppColors.goldDeep,
                        ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    if (_user != null &&
                        _region == CountryRegion.asean)
                      Marker(
                        point: LatLng(_user!.lat, _user!.lng),
                        width: 44,
                        height: 44,
                        child: UserDot(pulse: _pulse),
                      ),
                    for (final c in ordered)
                      Marker(
                        point: LatLng(c.lat, c.lng),
                        width: CountryPin.width,
                        height: CountryPin.height,
                        child: CountryPin(
                          country: c,
                          selected: c.code == _selected,
                          dimmed: !matching.contains(c.code),
                          pulse: _pulse,
                          bubble: c.code == _selected
                              ? '${c.name}${_distance(c) == null ? '' : ' · ${GeoUtils.formatKm(_distance(c)!)}'}'
                              : null,
                          onTap: () => _focus(c, sheet: true),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // ---- pudar putih di belakang header ----
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: safeTop + 200,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(.95),
                      Colors.white.withOpacity(.75),
                      Colors.white.withOpacity(0),
                    ],
                    stops: const [0, .6, 1],
                  ),
                ),
              ),
            ),
          ),

          // ---- header + pencarian + chip ----
          Positioned(
            top: safeTop + 8,
            left: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _reveal(0, _header()),
                const SizedBox(height: 12),
                _reveal(1, _searchRow()),
                const SizedBox(height: 10),
                _reveal(2, _chipsRow(pool)),
              ],
            ),
          ),

          // ---- kontrol peta ----
          Positioned(
            right: 12,
            top: safeTop + 196,
            child: MapControls(
              headings: _headings,
              onZoomIn: () => _zoomBy(1),
              onZoomOut: () => _zoomBy(-1),
              onMyLocation: _goToMe,
            ),
          ),

          // ---- atribusi OpenStreetMap (wajib) ----
          Positioned(
            left: 12,
            top: safeTop + 200,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.85),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '© OpenStreetMap contributors',
                style: TextStyle(fontSize: 10, color: AppColors.muted),
              ),
            ),
          ),

          // ---- carousel / detail ----
          Positioned(
            left: 0,
            right: 0,
            bottom: navSpace,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position:
                      Tween<Offset>(begin: const Offset(0, .12), end: Offset.zero)
                          .animate(anim),
                  child: child,
                ),
              ),
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.bottomCenter,
                children: [...previous, if (current != null) current],
              ),
              child: panel,
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    final done =
        _countries.where((c) => c.status == CountryStatus.selesai).length;
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
            boxShadow: [
              BoxShadow(color: AppColors.ink.withOpacity(.2), blurRadius: 8),
            ],
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
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: AppColors.ink.withOpacity(.18),
                  blurRadius: 16,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: TextField(
              controller: _search,
              onChanged: (v) => _filtersChanged(() => _query = v),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Cari negara atau ibukota',
                hintStyle: const TextStyle(color: AppColors.hint, fontSize: 14),
                prefixIcon:
                    const Icon(Icons.search_rounded, color: AppColors.muted),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Hapus',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _search.clear();
                          _filtersChanged(() => _query = '');
                        },
                      ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                border: _fieldBorder,
                enabledBorder: _fieldBorder,
                focusedBorder: _fieldBorder.copyWith(
                  borderSide:
                      const BorderSide(color: AppColors.teal, width: 1.6),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        RoundIconButton(
          icon: Icons.tune_rounded,
          label: 'Urutkan',
          size: 52,
          onTap: _openSort,
        ),
      ],
    );
  }

  Widget _chipsRow(List<Country> pool) {
    int n(CountryStatus s) => pool.where((c) => c.status == s).length;
    final defs = <(String, CountryStatus?)>[
      ('Semua · ${pool.length}', null),
      ('Terbuka · ${n(CountryStatus.terbuka)}', CountryStatus.terbuka),
      ('Selesai · ${n(CountryStatus.selesai)}', CountryStatus.selesai),
      ('Terkunci · ${n(CountryStatus.terkunci)}', CountryStatus.terkunci),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          RegionToggle(region: _region, onChanged: _setRegion),
          for (final d in defs)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _FilterPill(
                label: d.$1,
                selected: _status == d.$2,
                onTap: () {
                  HapticFeedback.selectionClick();
                  _filtersChanged(() => _status = d.$2);
                },
              ),
            ),
        ],
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
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.ink : Colors.white,
            borderRadius: BorderRadius.circular(21),
            boxShadow: [
              BoxShadow(color: AppColors.ink.withOpacity(.14), blurRadius: 10),
            ],
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

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: AppColors.ink.withOpacity(.2), blurRadius: 20),
        ],
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.travel_explore_rounded, size: 32, color: AppColors.hint),
          SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tidak ada negara yang cocok',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              Text('Coba kata kunci atau filter lain.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
            ],
          ),
        ],
      ),
    );
  }
}

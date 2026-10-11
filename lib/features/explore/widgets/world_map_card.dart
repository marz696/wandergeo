import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/services/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../models/country.dart';
import 'country_marker.dart';
import 'land_painter.dart';
import 'map_geometry.dart';

/// Kartu peta: pengalih ASEAN/UK, kompas (sensor), legenda, penanda negara.
class WorldMapCard extends StatefulWidget {
  const WorldMapCard({
    super.key,
    required this.region,
    required this.countries,
    required this.matchingCodes,
    required this.selectedCode,
    required this.userLocation,
    required this.headings,
    required this.onRegionChanged,
    required this.onSelect,
  });

  final CountryRegion region;
  final List<Country> countries;
  final Set<String> matchingCodes;
  final String? selectedCode;
  final UserLocation? userLocation;
  final Stream<double?> headings;
  final ValueChanged<CountryRegion> onRegionChanged;
  final ValueChanged<Country> onSelect;

  @override
  State<WorldMapCard> createState() => _WorldMapCardState();
}

class _WorldMapCardState extends State<WorldMapCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 320,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFDCEEF6), Color(0xFFCBE3EE)],
        ),
        border: Border.all(color: const Color(0xFFC3DCE8)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(23),
        child: LayoutBuilder(
          builder: (context, box) {
            final size = Size(box.maxWidth, box.maxHeight);
            return Stack(
              children: [
                Positioned.fill(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 380),
                    child: _MapLayer(
                      key: ValueKey(widget.region),
                      region: widget.region,
                      countries: widget.countries,
                      matchingCodes: widget.matchingCodes,
                      selectedCode: widget.selectedCode,
                      user: widget.userLocation,
                      size: size,
                      pulse: _pulse,
                      onSelect: widget.onSelect,
                    ),
                  ),
                ),
                Positioned(
                  left: 10,
                  top: 10,
                  child: _RegionToggle(
                    region: widget.region,
                    onChanged: widget.onRegionChanged,
                  ),
                ),
                Positioned(
                  right: 10,
                  top: 10,
                  child: _CompassButton(headings: widget.headings),
                ),
                const Positioned(left: 10, bottom: 10, child: _Legend()),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MapLayer extends StatefulWidget {
  const _MapLayer({
    super.key,
    required this.region,
    required this.countries,
    required this.matchingCodes,
    required this.selectedCode,
    required this.user,
    required this.size,
    required this.pulse,
    required this.onSelect,
  });

  final CountryRegion region;
  final List<Country> countries;
  final Set<String> matchingCodes;
  final String? selectedCode;
  final UserLocation? user;
  final Size size;
  final Animation<double> pulse;
  final ValueChanged<Country> onSelect;

  @override
  State<_MapLayer> createState() => _MapLayerState();
}

class _MapLayerState extends State<_MapLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final geo = MapGeometry.of(widget.region);
    final size = widget.size;
    final points = {
      for (final c in widget.countries) c.code: geo.toLocal(size, c.lat, c.lng),
    };

    final Offset? user = _userPoint(geo, size);
    final target =
        widget.selectedCode == null ? null : points[widget.selectedCode];

    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: LandPainter(
                  geometry: geo,
                  reveal: Curves.easeOut.transform(_c.value),
                  user: user,
                  target: target,
                ),
              ),
            ),
            if (user != null)
              Positioned(
                left: user.dx - 14,
                top: user.dy - 14,
                child: _UserDot(pulse: widget.pulse),
              ),
            for (var i = 0; i < widget.countries.length; i++)
              _positioned(widget.countries[i], points, i),
          ],
        );
      },
    );
  }

  Offset? _userPoint(MapGeometry geo, Size size) {
    final u = widget.user;
    if (u == null) return null;
    final p = geo.toLocal(size, u.lat, u.lng);
    return (Offset.zero & size).contains(p) ? p : null;
  }

  Widget _positioned(Country c, Map<String, Offset> points, int i) {
    final p = points[c.code]!;
    final t = ((_c.value - .25 - i * .05) / .4).clamp(0.0, 1.0);
    final matches = widget.matchingCodes.contains(c.code);
    return Positioned(
      left: p.dx - 24,
      top: p.dy - 22,
      width: 48,
      child: Opacity(
        opacity: math.min(1.0, t * 2),
        child: Transform.scale(
          scale: Curves.easeOutBack.transform(t),
          child: CountryMarker(
            country: c,
            selected: widget.selectedCode == c.code,
            dimmed: !matches,
            pulse: widget.pulse,
            onTap: () => widget.onSelect(c),
          ),
        ),
      ),
    );
  }
}

class _UserDot extends StatelessWidget {
  const _UserDot({required this.pulse});

  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: 28,
        height: 28,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: pulse,
              builder: (_, __) => Container(
                width: 12 + 16 * pulse.value,
                height: 12 + 16 * pulse.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF2F80ED)
                      .withOpacity((1 - pulse.value) * .35),
                ),
              ),
            ),
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2F80ED),
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RegionToggle extends StatelessWidget {
  const _RegionToggle({required this.region, required this.onChanged});

  final CountryRegion region;
  final ValueChanged<CountryRegion> onChanged;

  @override
  Widget build(BuildContext context) {
    final asean = region == CountryRegion.asean;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(.08), blurRadius: 8),
        ],
      ),
      child: SizedBox(
        width: 150,
        height: 40,
        child: Stack(
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              alignment: asean ? Alignment.centerLeft : Alignment.centerRight,
              child: Container(
                width: 75,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            Row(
              children: [
                _seg('ASEAN', asean, CountryRegion.asean),
                _seg('UK', !asean, CountryRegion.uk),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _seg(String label, bool active, CountryRegion value) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: active,
        label: 'Wilayah $label',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(value),
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: active ? Colors.white : AppColors.muted,
              ),
              child: Text(label),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompassButton extends StatelessWidget {
  const _CompassButton({required this.headings});

  final Stream<double?> headings;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<double?>(
      stream: headings,
      builder: (context, snap) {
        final heading = snap.data ?? 0;
        return Semantics(
          label: 'Kompas, arah ${heading.round()} derajat',
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(.08), blurRadius: 8),
              ],
            ),
            child: Transform.rotate(
              angle: -heading * math.pi / 180,
              child: const Icon(
                Icons.navigation_rounded,
                color: AppColors.error,
                size: 24,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    Widget item(Color c, String t) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text(
              t,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.deepNavy,
              ),
            ),
          ],
        );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.94),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          item(AppColors.success, 'Selesai'),
          const SizedBox(width: 10),
          item(AppColors.teal, 'Terbuka'),
          const SizedBox(width: 10),
          item(AppColors.hint, 'Terkunci'),
        ],
      ),
    );
  }
}

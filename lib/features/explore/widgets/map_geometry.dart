import 'dart:math' as math;
import 'dart:ui';

import '../models/country.dart';

/// Peta ilustrasi: bentuk daratan + proyeksi lat/lng ke koordinat desain,
/// lalu diskalakan agar pas di ukuran kartu.
class MapGeometry {
  MapGeometry._(this.rect, this._project, this.land);

  /// Area desain yang ditampilkan.
  final Rect rect;
  final Offset Function(double lat, double lng) _project;

  /// Poligon daratan (koordinat desain).
  final List<List<Offset>> land;

  static MapGeometry of(CountryRegion region) =>
      region == CountryRegion.asean ? asean : uk;

  static List<Offset> _pts(List<double> v) =>
      [for (var i = 0; i < v.length; i += 2) Offset(v[i], v[i + 1])];

  static final MapGeometry asean = MapGeometry._(
    const Rect.fromLTWH(0, 190, 390, 395),
    (lat, lng) => Offset((lng - 94) * 12.19, (26 - lat) * 12.19 + 140),
    [
      // Daratan utama Asia Tenggara + Semenanjung Malaya
      _pts([0, 150, 150, 150, 165, 215, 160, 260, 150, 300, 135, 338, 118, 338, 104, 318, 96, 330, 92, 350, 96, 385, 104, 410, 112, 432, 100, 432, 90, 415, 80, 385, 70, 350, 55, 315, 40, 260, 35, 235, 22, 210, 10, 190, 0, 175]),
      // Sumatra
      _pts([10, 380, 30, 372, 150, 490, 165, 520, 150, 528, 110, 500, 40, 425]),
      // Jawa
      _pts([140, 525, 250, 535, 250, 550, 150, 545]),
      // Kalimantan
      _pts([190, 420, 215, 385, 255, 375, 295, 395, 305, 430, 300, 480, 260, 505, 215, 495, 190, 460]),
      // Sulawesi
      _pts([320, 440, 345, 435, 335, 470, 360, 490, 350, 495, 330, 480, 325, 520, 315, 500, 318, 470]),
      // Luzon
      _pts([322, 235, 340, 232, 346, 270, 338, 295, 318, 285, 320, 255]),
      // Mindanao
      _pts([345, 345, 380, 340, 388, 365, 360, 385, 342, 370]),
      // Timor
      _pts([350, 558, 378, 552, 380, 562, 352, 568]),
    ],
  );

  static final MapGeometry uk = _buildUk();

  static MapGeometry _buildUk() {
    Offset proj(double lat, double lng) =>
        Offset((lng + 11) * 30, (59 - lat) * 30);
    List<Offset> poly(List<double> v) =>
        [for (var i = 0; i < v.length; i += 2) proj(v[i], v[i + 1])];
    return MapGeometry._(
      const Rect.fromLTWH(0, 0, 405, 285),
      proj,
      [
        // Britania Raya (lat, lng)
        poly([50.0, -5.7, 50.6, -2.0, 50.8, 0.3, 51.1, 1.4, 51.5, 0.9, 52.9, 1.7, 53.5, 0.1, 54.5, -1.1, 55.8, -2.0, 56.0, -3.0, 57.5, -1.8, 57.6, -3.5, 58.6, -3.0, 58.6, -5.0, 57.5, -5.8, 56.5, -5.5, 55.6, -5.2, 54.9, -5.0, 54.7, -3.4, 53.4, -3.1, 53.3, -4.6, 52.5, -4.1, 51.7, -5.2, 51.2, -4.2, 51.2, -3.2, 50.9, -3.5, 50.2, -5.1]),
        // Irlandia
        poly([51.5, -9.5, 52.1, -10.3, 53.3, -9.9, 54.3, -10.0, 55.2, -7.4, 54.5, -5.6, 53.4, -6.1, 52.2, -6.3, 51.5, -8.0]),
      ],
    );
  }

  double scaleFor(Size size) =>
      math.min(size.width / rect.width, size.height / rect.height) * 0.9;

  Offset originFor(Size size, double scale) => Offset(
        (size.width - rect.width * scale) / 2,
        (size.height - rect.height * scale) / 2,
      );

  Offset designToLocal(Offset d, Size size) {
    final s = scaleFor(size);
    final o = originFor(size, s);
    return Offset((d.dx - rect.left) * s + o.dx, (d.dy - rect.top) * s + o.dy);
  }

  /// Posisi lat/lng pada kanvas berukuran [size].
  Offset toLocal(Size size, double lat, double lng) =>
      designToLocal(_project(lat, lng), size);
}

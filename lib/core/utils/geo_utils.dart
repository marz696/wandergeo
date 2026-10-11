import 'dart:math' as math;

class GeoUtils {
  GeoUtils._();

  static const double _earthRadiusKm = 6371.0;

  /// Jarak dua koordinat (km) dengan rumus haversine.
  static double haversineKm(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    double rad(double d) => d * math.pi / 180;
    final dLat = rad(lat2 - lat1);
    final dLng = rad(lng2 - lng1);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(lat1)) *
            math.cos(rad(lat2)) *
            math.pow(math.sin(dLng / 2), 2);
    return 2 * _earthRadiusKm * math.asin(math.min(1.0, math.sqrt(a)));
  }

  /// 1950.4 -> "≈ 1.950 km", 4.26 -> "≈ 4,3 km".
  static String formatKm(double km) {
    if (km < 10) return '≈ ${km.toStringAsFixed(1).replaceAll('.', ',')} km';
    final grouped = km.round().toString().replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (_) => '.',
        );
    return '≈ $grouped km';
  }
}

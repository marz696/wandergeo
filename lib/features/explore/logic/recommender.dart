import '../../../core/services/location_service.dart';
import '../../../core/utils/geo_utils.dart';
import '../models/country.dart';

/// Fitur AI (non-LLM): rekomendasi negara berikutnya.
/// Skor = tingkat kesulitan (dominan) + jarak (penentu seri); skor terkecil menang.
Country? recommendNext(List<Country> pool, UserLocation? user) {
  final open = pool.where((c) => c.status == CountryStatus.terbuka).toList();
  if (open.isEmpty) return null;
  double score(Country c) {
    final km = user == null
        ? 0.0
        : GeoUtils.haversineKm(user.lat, user.lng, c.lat, c.lng);
    return c.difficulty * 100000 + km;
  }

  open.sort((a, b) => score(a).compareTo(score(b)));
  return open.first;
}

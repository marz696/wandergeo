import 'dart:convert';

import 'package:http/http.dart' as http;

class WeatherInfo {
  const WeatherInfo({required this.tempC, required this.code});

  final double tempC;
  final int code;

  /// Kode cuaca WMO -> teks singkat.
  String get label {
    if (code == 0) return 'Cerah';
    if (code <= 2) return 'Cerah berawan';
    if (code == 3) return 'Berawan';
    if (code == 45 || code == 48) return 'Berkabut';
    if (code >= 51 && code <= 57) return 'Gerimis';
    if (code >= 61 && code <= 67) return 'Hujan';
    if (code >= 71 && code <= 77) return 'Salju';
    if (code >= 80 && code <= 82) return 'Hujan lebat';
    if (code >= 95) return 'Badai petir';
    return 'Berawan';
  }

  String get text => '${tempC.round()}°C · $label';
}

/// Cuaca saat ini di ibukota lewat Open-Meteo (gratis, tanpa API key,
/// untuk pemakaian non-komersial). Di-cache 15 menit.
class WeatherService {
  WeatherService._();

  static final WeatherService instance = WeatherService._();

  final Map<String, (DateTime, WeatherInfo)> _cache = {};

  Future<WeatherInfo?> fetch(String code, double lat, double lng) async {
    final hit = _cache[code];
    if (hit != null &&
        DateTime.now().difference(hit.$1) < const Duration(minutes: 15)) {
      return hit.$2;
    }
    try {
      final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': '$lat',
        'longitude': '$lng',
        'current': 'temperature_2m,weather_code',
      });
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final cur = json['current'] as Map<String, dynamic>;
      final info = WeatherInfo(
        tempC: (cur['temperature_2m'] as num).toDouble(),
        code: (cur['weather_code'] as num).toInt(),
      );
      _cache[code] = (DateTime.now(), info);
      return info;
    } catch (_) {
      return null;
    }
  }
}

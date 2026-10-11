import 'package:geolocator/geolocator.dart';

class UserLocation {
  const UserLocation(this.lat, this.lng, {this.approximate = false});

  final double lat;
  final double lng;

  /// true bila izin/GPS tidak tersedia dan memakai lokasi cadangan.
  final bool approximate;
}

/// LBS: posisi pengguna untuk menghitung jarak ke tiap negara.
class LocationService {
  /// Cadangan bila GPS mati atau izin ditolak (Jakarta).
  static const fallback = UserLocation(-6.2088, 106.8456, approximate: true);

  Future<UserLocation> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return fallback;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return fallback;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 8),
        ),
      );
      return UserLocation(pos.latitude, pos.longitude);
    } catch (_) {
      return fallback;
    }
  }
}

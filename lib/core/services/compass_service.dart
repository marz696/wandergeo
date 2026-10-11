import 'package:flutter_compass/flutter_compass.dart';

/// Sensor 1: magnetometer (arah kompas dalam derajat, 0 = utara).
/// Emit null bila perangkat/emulator tidak punya sensor.
class CompassService {
  Stream<double?> get headings {
    final events = FlutterCompass.events;
    if (events == null) return Stream<double?>.value(null);
    return events.map((e) => e.heading);
  }
}

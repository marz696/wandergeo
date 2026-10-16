import 'package:flutter/material.dart' show TimeOfDay;
import 'package:shared_preferences/shared_preferences.dart';

/// Pengaturan notifikasi (per perangkat), disimpan di SharedPreferences.
class NotificationPrefs {
  const NotificationPrefs({
    this.reminder = false,
    this.hour = 19,
    this.minute = 0,
    this.events = true,
    this.asked = false,
  });

  /// Pengingat misi harian aktif.
  final bool reminder;
  final int hour;
  final int minute;

  /// Notifikasi pencapaian (negara selesai / negara baru terbuka).
  final bool events;

  /// Ajakan awal ("Aktifkan pengingat?") sudah pernah ditampilkan.
  final bool asked;

  TimeOfDay get time => TimeOfDay(hour: hour, minute: minute);

  NotificationPrefs copyWith({
    bool? reminder,
    int? hour,
    int? minute,
    bool? events,
    bool? asked,
  }) =>
      NotificationPrefs(
        reminder: reminder ?? this.reminder,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
        events: events ?? this.events,
        asked: asked ?? this.asked,
      );

  static Future<NotificationPrefs> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      return NotificationPrefs(
        reminder: p.getBool('notif_reminder') ?? false,
        hour: p.getInt('notif_hour') ?? 19,
        minute: p.getInt('notif_minute') ?? 0,
        events: p.getBool('notif_events') ?? true,
        asked: p.getBool('notif_asked') ?? false,
      );
    } catch (_) {
      return const NotificationPrefs();
    }
  }

  Future<void> save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool('notif_reminder', reminder);
      await p.setInt('notif_hour', hour);
      await p.setInt('notif_minute', minute);
      await p.setBool('notif_events', events);
      await p.setBool('notif_asked', asked);
    } catch (_) {}
  }
}

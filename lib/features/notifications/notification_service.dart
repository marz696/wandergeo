import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'notification_prefs.dart';

/// Pembungkus flutter_local_notifications (notifikasi lokal, tanpa server/Firebase).
///
/// Pengingat harian dijadwalkan untuk 7 hari ke depan dan dijadwalkan ulang tiap
/// aplikasi dibuka, sehingga isi pesannya bisa mengikuti progres pengguna dan
/// berhenti sendiri bila aplikasi lama tidak dibuka.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const _icon = 'ic_stat_wandergeo';
  static const _reminderBase = 100; // id 100..106
  static const _reminderDays = 7;

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  bool _unsupported = false;

  /// Aman dipanggil berulang. Di web / bila gagal, semua fungsi menjadi no-op.
  Future<void> init() async {
    if (_ready || _unsupported) return;
    if (kIsWeb) {
      _unsupported = true;
      return;
    }
    try {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.UTC); // jadwal dihitung dari waktu lokal HP -> UTC
      const android = AndroidInitializationSettings(_icon);
      final darwin = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _plugin.initialize(
        settings: InitializationSettings(android: android, iOS: darwin),
      );
      _ready = true;
    } catch (_) {
      _unsupported = true;
    }
  }

  /// Meminta izin notifikasi (Android 13+ / iOS). true bila diizinkan.
  Future<bool> requestPermission() async {
    await init();
    if (!_ready) return false;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        return (await android.requestNotificationsPermission()) ?? false;
      }
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        return (await ios.requestPermissions(alert: true, badge: true, sound: true)) ??
            false;
      }
    } catch (_) {}
    return false;
  }

  NotificationDetails _details({required bool event}) => NotificationDetails(
        android: AndroidNotificationDetails(
          event ? 'wandergeo_event' : 'wandergeo_reminder',
          event ? 'Pencapaian' : 'Pengingat harian',
          channelDescription: event
              ? 'Negara selesai dan negara baru terbuka'
              : 'Pengingat misi setiap hari',
          importance: event ? Importance.high : Importance.defaultImportance,
          priority: event ? Priority.high : Priority.defaultPriority,
          icon: _icon,
        ),
        iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true),
      );

  /// Menjadwalkan pengingat harian pukul [time] (waktu lokal HP) untuk 7 hari.
  /// [bodies] = 7 teks, satu per hari.
  Future<void> scheduleReminders({
    required TimeOfDay time,
    required List<String> bodies,
  }) async {
    await init();
    if (!_ready || bodies.isEmpty) return;
    await cancelReminders();
    final now = DateTime.now();
    for (var i = 0; i < _reminderDays; i++) {
      final at = DateTime(now.year, now.month, now.day + i, time.hour, time.minute);
      if (!at.isAfter(now.add(const Duration(minutes: 1)))) continue; // sudah lewat
      try {
        await _plugin.zonedSchedule(
          id: _reminderBase + i,
          title: 'WanderGeo',
          body: bodies[i % bodies.length],
          scheduledDate: tz.TZDateTime.from(at.toUtc(), tz.UTC),
          notificationDetails: _details(event: false),
          // Tidak butuh izin alarm eksak; bisa tertunda beberapa menit.
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: 'reminder',
        );
      } catch (_) {
        // Gagal menjadwalkan satu hari tidak boleh menghentikan aplikasi.
      }
    }
  }

  Future<void> cancelReminders() async {
    await init();
    if (!_ready) return;
    for (var i = 0; i < _reminderDays; i++) {
      try {
        await _plugin.cancel(id: _reminderBase + i);
      } catch (_) {}
    }
  }

  /// Notifikasi seketika (mis. negara selesai). Mengikuti pengaturan "pencapaian".
  Future<void> showEvent({required String title, required String body, bool force = false}) async {
    await init();
    if (!_ready) return;
    if (!force && !(await NotificationPrefs.load()).events) return;
    try {
      await _plugin.show(
        id: 1000 + (DateTime.now().millisecondsSinceEpoch % 100000),
        title: title,
        body: body,
        notificationDetails: _details(event: true),
        payload: 'event',
      );
    } catch (_) {}
  }
}

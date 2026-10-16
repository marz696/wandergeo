import '../explore/data/country_repository.dart';
import '../explore/models/country.dart';
import 'notification_prefs.dart';
import 'notification_service.dart';

/// Menyusun isi notifikasi dari progres pengguna lalu menjadwalkannya.
class NotificationPlanner {
  NotificationPlanner._();

  /// 7 teks pengingat (satu per hari), mengikuti negara yang sedang terbuka.
  static List<String> reminderBodies(List<Country> countries) {
    final open = countries.where((c) => c.status == CountryStatus.terbuka).toList()
      ..sort((a, b) => a.difficulty.compareTo(b.difficulty));
    final next = open.isEmpty ? null : open.first.name;
    final done = countries.where((c) => c.status == CountryStatus.selesai).length;
    final total = countries.length;
    return [
      next != null
          ? 'Ayo lanjutkan petualanganmu di $next. Ada misi yang menunggu!'
          : 'Semua negara terbuka sudah selesai. Cek paspor digitalmu!',
      'Satu misi kecil hari ini membawamu selangkah lebih dekat ke stempel baru.',
      'Kuota Tanya Pemandu hari ini sudah segar lagi. Tanyakan sesuatu tentang ${next ?? 'negara favoritmu'}!',
      total > 0
          ? 'Baru $done dari $total negara yang selesai. Yuk tambah satu hari ini!'
          : 'Yuk lanjutkan petualangan geografimu hari ini!',
      'Waktunya latihan: coba trivia ${next ?? 'negara pilihanmu'} dan kumpulkan koin.',
      'Mini game Tangkap Koin menunggumu. Miringkan HP dan kumpulkan skor!',
      'Cek paspor digitalmu dan lihat stempel yang sudah kamu kumpulkan.',
    ];
  }

  /// Jadwalkan ulang pengingat (dipanggil tiap Eksplorasi memuat data).
  static Future<void> refresh(List<Country> countries) async {
    if (countries.isEmpty) return;
    final prefs = await NotificationPrefs.load();
    if (!prefs.reminder) return;
    await NotificationService.instance.scheduleReminders(
      time: prefs.time,
      bodies: reminderBodies(countries),
    );
  }

  /// Sama seperti [refresh], tetapi membaca negara dari SQLite (untuk halaman pengaturan).
  static Future<void> refreshFromLocal(String userId) async {
    final countries = await CountryRepository().loadLocal(userId);
    await refresh(countries);
  }

  /// Notifikasi saat sebuah negara baru selesai.
  static Future<void> countryCompleted({
    required String country,
    required List<String> unlocked,
  }) {
    final body = unlocked.isEmpty
        ? 'Stempel paspor $country sudah kamu dapatkan.'
        : 'Stempel $country didapat! ${unlocked.join(' dan ')} kini terbuka.';
    return NotificationService.instance.showEvent(title: '$country selesai!', body: body);
  }
}

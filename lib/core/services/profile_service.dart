import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Foto profil lokal, satu foto per akun (nama file memakai id user), jadi
/// akun lain di perangkat yang sama tidak melihat foto ini.
///
/// Foto dikembalikan sebagai bytes supaya satu kode jalan di HP dan di web:
/// - HP (Android/iOS): disimpan sebagai file di folder dokumen aplikasi.
/// - Web: disimpan di memori saja (hilang saat halaman dimuat ulang), karena
///   browser tidak punya folder dokumen untuk aplikasi.
///
/// Nama, username, email, dan gelar TIDAK diurus di sini; semuanya dari
/// tabel `users` lewat AuthRepository.
class ProfileService {
  ProfileService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  static final Map<String, Uint8List> _webMemory = {};

  Future<File> _file(String userId) async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/profile_$userId.jpg');
  }

  Future<Uint8List?> readPhoto(String userId) async {
    if (kIsWeb) return _webMemory[userId];
    final file = await _file(userId);
    if (!file.existsSync()) return null;
    return file.readAsBytes();
  }

  /// Mengambil foto dari kamera/galeri. Mengembalikan null jika dibatalkan.
  Future<Uint8List?> pickPhoto(String userId, ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 900,
      maxHeight: 900,
      imageQuality: 85,
    );
    if (picked == null) return null;

    final bytes = await picked.readAsBytes();
    if (kIsWeb) {
      _webMemory[userId] = bytes;
      return bytes;
    }
    final file = await _file(userId);
    await file.writeAsBytes(bytes, flush: true);
    return bytes;
  }

  Future<void> removePhoto(String userId) async {
    if (kIsWeb) {
      _webMemory.remove(userId);
      return;
    }
    final file = await _file(userId);
    if (file.existsSync()) await file.delete();
  }
}
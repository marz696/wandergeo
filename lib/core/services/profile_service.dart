import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// Mengambil foto profil dari kamera/galeri.
///
/// Foto TIDAK disimpan di perangkat. Setelah dipilih, bytes-nya diunggah ke
/// Supabase Storage lewat `AuthRepository.uploadAvatar`, dan link publiknya
/// disimpan di kolom `users.avatar_url`. Jadi foto ikut akun, bukan perangkat.
///
/// Gambar sudah dikecilkan di sini (maks 900 px, kualitas 85) supaya unggahan
/// ringan dan jauh di bawah batas 2 MB di server.
class ProfileService {
  ProfileService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// Mengembalikan null jika pengguna membatalkan.
  Future<Uint8List?> pickPhoto(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 900,
      maxHeight: 900,
      imageQuality: 85,
    );
    if (picked == null) return null;
    return picked.readAsBytes();
  }
}

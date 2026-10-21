import 'dart:ui' show Rect;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Satu blok teks yang terbaca dari foto, beserta posisinya (dalam piksel foto).
class OcrBlock {
  const OcrBlock({required this.text, required this.box});

  final String text;
  final Rect box;
}

/// Membaca teks dari foto memakai ML Kit Text Recognition. Seluruh proses
/// berjalan di perangkat. Aksara yang dipakai adalah Latin, cukup untuk
/// bahasa Inggris, Melayu, Vietnam, dan Filipino.
class OcrService {
  Future<List<OcrBlock>> read(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result =
          await recognizer.processImage(InputImage.fromFilePath(imagePath));
      return [
        for (final b in result.blocks)
          if (b.text.trim().isNotEmpty)
            OcrBlock(
              // Baris dalam satu blok digabung agar terjemahannya mengalir.
              text: b.text.replaceAll('\n', ' ').trim(),
              box: b.boundingBox,
            ),
      ];
    } finally {
      await recognizer.close();
    }
  }
}

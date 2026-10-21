import 'package:google_mlkit_translation/google_mlkit_translation.dart';

/// Bahasa pada foto yang bisa dipilih. Semuanya beraksara Latin supaya
/// bisa dibaca oleh pembaca teks.
class SourceLanguage {
  const SourceLanguage(this.label, this.language, this.usedIn);

  final String label;
  final TranslateLanguage language;
  final String usedIn;
}

const kSourceLanguages = <SourceLanguage>[
  SourceLanguage(
    'Inggris',
    TranslateLanguage.english,
    'Inggris Raya, Singapura, dan Filipina',
  ),
  SourceLanguage(
    'Melayu',
    TranslateLanguage.malay,
    'Malaysia, Brunei, dan Singapura',
  ),
  SourceLanguage('Vietnam', TranslateLanguage.vietnamese, 'Vietnam'),
  SourceLanguage('Filipino', TranslateLanguage.tagalog, 'Filipina'),
];

/// Model bahasa gagal diunduh (biasanya karena tidak ada internet).
class ModelDownloadException implements Exception {
  const ModelDownloadException();
}

/// Terjemahan ke bahasa Indonesia memakai ML Kit On-Device Translation.
/// Model tiap bahasa diunduh sekali, setelah itu bisa dipakai tanpa internet.
class TranslateService {
  final _models = OnDeviceTranslatorModelManager();

  static const target = TranslateLanguage.indonesian;

  /// True bila model bahasa sumber dan model Indonesia sudah ada di perangkat.
  Future<bool> modelsReady(TranslateLanguage source) async {
    return await _models.isModelDownloaded(source.bcpCode) &&
        await _models.isModelDownloaded(target.bcpCode);
  }

  Future<void> downloadModels(TranslateLanguage source) async {
    for (final lang in [source, target]) {
      if (await _models.isModelDownloaded(lang.bcpCode)) continue;
      var ok = false;
      try {
        ok = await _models.downloadModel(lang.bcpCode, isWifiRequired: false);
      } catch (_) {
        ok = false;
      }
      if (!ok) throw const ModelDownloadException();
    }
  }

  Future<List<String>> translateAll(
    TranslateLanguage source,
    List<String> texts,
  ) async {
    final translator = OnDeviceTranslator(
      sourceLanguage: source,
      targetLanguage: target,
    );
    try {
      final out = <String>[];
      for (final t in texts) {
        out.add((await translator.translateText(t)).trim());
      }
      return out;
    } finally {
      await translator.close();
    }
  }
}

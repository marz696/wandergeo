import 'dart:convert';

import 'package:http/http.dart' as http;

class WikiInfo {
  const WikiInfo({required this.summary, this.imageUrl});

  final String summary;
  final String? imageUrl;
}

class _Summary {
  const _Summary(this.extract, this.imageUrl);

  final String extract;
  final String? imageUrl;
}

/// Ringkasan negara + foto (dari artikel ibukota) lewat REST API Wikipedia
/// bahasa Indonesia. Gratis, tanpa API key; wajib mengirim User-Agent.
/// Hasil disimpan di memori selama aplikasi berjalan.
class WikipediaService {
  WikipediaService._();

  static final WikipediaService instance = WikipediaService._();

  // kode negara -> (judul artikel negara, judul artikel untuk foto)
  static const Map<String, (String, String)> _titles = {
    'ID': ('Indonesia', 'Jakarta'),
    'MY': ('Malaysia', 'Kuala Lumpur'),
    'SG': ('Singapura', 'Marina Bay Sands'),
    'TH': ('Thailand', 'Bangkok'),
    'VN': ('Vietnam', 'Hanoi'),
    'PH': ('Filipina', 'Manila'),
    'BN': ('Brunei', 'Bandar Seri Begawan'),
    'KH': ('Kamboja', 'Phnom Penh'),
    'LA': ('Laos', 'Vientiane'),
    'MM': ('Myanmar', 'Naypyidaw'),
    'TL': ('Timor Leste', 'Dili'),
    'GB': ('Britania Raya', 'London'),
  };

  final Map<String, Future<WikiInfo?>> _cache = {};

  Future<WikiInfo?> info(String code) =>
      _cache.putIfAbsent(code, () => _load(code));

  Future<WikiInfo?> _load(String code) async {
    final titles = _titles[code];
    if (titles == null) return null;
    final results = await Future.wait([_summary(titles.$1), _summary(titles.$2)]);
    final country = results[0];
    final city = results[1];
    if (country == null && city == null) {
      _cache.remove(code); // coba lagi nanti (mis. saat offline)
      return null;
    }
    return WikiInfo(
      summary: country?.extract ?? city?.extract ?? '',
      imageUrl: city?.imageUrl ?? country?.imageUrl,
    );
  }

  Future<_Summary?> _summary(String title) async {
    try {
      final uri = Uri.parse(
        'https://id.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(title)}',
      );
      final res = await http.get(uri, headers: const {
        'User-Agent': 'WanderGeo/1.0 (tugas kuliah PAM)',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final extract = (json['extract'] as String?)?.trim() ?? '';
      if (extract.isEmpty) return null;
      final thumb = json['thumbnail'];
      final image = thumb is Map<String, dynamic> ? thumb['source'] as String? : null;
      return _Summary(extract, image);
    } catch (_) {
      return null;
    }
  }
}

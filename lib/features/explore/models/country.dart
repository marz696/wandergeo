enum CountryStatus { terkunci, terbuka, selesai }

enum CountryRegion { asean, uk }

/// Label zona waktu untuk tampilan, dari nama zona IANA di tabel `countries`.
String utcLabelFor(String timezone) => switch (timezone) {
      'Asia/Jakarta' => 'UTC+7 (WIB)',
      'Asia/Bangkok' ||
      'Asia/Ho_Chi_Minh' ||
      'Asia/Phnom_Penh' ||
      'Asia/Vientiane' =>
        'UTC+7 (setara WIB)',
      'Asia/Kuala_Lumpur' ||
      'Asia/Singapore' ||
      'Asia/Manila' ||
      'Asia/Brunei' =>
        'UTC+8 (setara WITA)',
      'Asia/Dili' => 'UTC+9 (setara WIT)',
      'Asia/Yangon' => 'UTC+6:30',
      'Europe/London' => 'UTC+0 / +1 (BST)',
      _ => timezone,
    };

class Country {
  const Country({
    required this.code,
    required this.name,
    required this.capital,
    required this.language,
    required this.lat,
    required this.lng,
    required this.region,
    required this.currency,
    required this.utcLabel,
    required this.difficulty,
    this.timezone = '',
    this.population,
    this.flagUrl,
    this.status = CountryStatus.terkunci,
    this.bestScore = 0,
  });

  final String code;
  final String name;
  final String capital;
  final String language;
  final double lat;
  final double lng;
  final CountryRegion region;
  final String currency;
  final String utcLabel;
  final int difficulty;
  final String timezone;
  final int? population;
  final String? flagUrl;
  final CountryStatus status;
  final int bestScore;

  String get statusLabel => switch (status) {
        CountryStatus.selesai => 'selesai',
        CountryStatus.terbuka => 'terbuka',
        CountryStatus.terkunci => 'terkunci',
      };

  /// Dari baris tabel `countries` (JSON Supabase maupun baris SQLite;
  /// nama kolomnya sama). Status & skor diisi terpisah dari `user_progress`.
  factory Country.fromRow(Map<String, Object?> r) {
    final tz = (r['timezone'] as String?) ?? '';
    return Country(
      code: r['code'] as String,
      name: r['name'] as String,
      capital: r['capital'] as String,
      language: (r['language'] as String?) ?? '',
      lat: (r['latitude'] as num).toDouble(),
      lng: (r['longitude'] as num).toDouble(),
      region: r['region'] == 'UK' ? CountryRegion.uk : CountryRegion.asean,
      currency: r['currency_code'] as String,
      utcLabel: utcLabelFor(tz),
      difficulty: (r['difficulty'] as num?)?.toInt() ?? 1,
      timezone: tz,
      population: (r['population'] as num?)?.toInt(),
      flagUrl: r['flag_url'] as String?,
    );
  }

  Map<String, Object?> toRow() => {
        'code': code,
        'name': name,
        'capital': capital,
        'language': language,
        'population': population,
        'flag_url': flagUrl,
        'latitude': lat,
        'longitude': lng,
        'region': region == CountryRegion.uk ? 'UK' : 'ASEAN',
        'timezone': timezone,
        'currency_code': currency,
        'difficulty': difficulty,
      };

  Country copyWith({CountryStatus? status, int? bestScore}) => Country(
        code: code,
        name: name,
        capital: capital,
        language: language,
        lat: lat,
        lng: lng,
        region: region,
        currency: currency,
        utcLabel: utcLabel,
        difficulty: difficulty,
        timezone: timezone,
        population: population,
        flagUrl: flagUrl,
        status: status ?? this.status,
        bestScore: bestScore ?? this.bestScore,
      );
}

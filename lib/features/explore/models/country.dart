enum CountryStatus { terkunci, terbuka, selesai }

enum CountryRegion { asean, uk }

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
  final CountryStatus status;
  final int bestScore;

  String get statusLabel => switch (status) {
        CountryStatus.selesai => 'selesai',
        CountryStatus.terbuka => 'terbuka',
        CountryStatus.terkunci => 'terkunci',
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
        status: status ?? this.status,
        bestScore: bestScore ?? this.bestScore,
      );
}

/// Satu blok di rantai paspor. Blok 0 (genesis) tidak punya negara.
class PassportBlock {
  const PassportBlock({
    required this.index,
    required this.countryCode,
    required this.countryName,
    required this.capital,
    required this.flagUrl,
    required this.score,
    required this.timestamp,
    required this.previousHash,
    required this.hash,
    required this.nonce,
    required this.valid,
  });

  final int index;
  final String? countryCode;
  final String? countryName;
  final String? capital;
  final String? flagUrl;
  final int score;
  final DateTime timestamp;
  final String previousHash;
  final String hash;
  final int nonce;
  final bool valid;

  bool get isGenesis => countryCode == null;

  factory PassportBlock.fromJson(Map<String, dynamic> j) => PassportBlock(
        index: (j['index'] as num).toInt(),
        countryCode: j['country_code'] as String?,
        countryName: j['country_name'] as String?,
        capital: j['capital'] as String?,
        flagUrl: j['flag_url'] as String?,
        score: (j['score'] as num?)?.toInt() ?? 0,
        timestamp: DateTime.tryParse(j['timestamp'] as String? ?? '')?.toLocal() ??
            DateTime.now(),
        previousHash: j['previous_hash'] as String? ?? '',
        hash: j['hash'] as String? ?? '',
        nonce: (j['nonce'] as num?)?.toInt() ?? 0,
        valid: (j['valid'] as bool?) ?? false,
      );
}

/// Isi paspor + hasil verifikasi rantai dari server.
class PassportData {
  const PassportData({
    required this.valid,
    required this.brokenAt,
    required this.totalCountries,
    required this.stamps,
    required this.blocks,
  });

  final bool valid;
  final int? brokenAt;
  final int totalCountries;
  final int stamps;
  final List<PassportBlock> blocks;

  factory PassportData.fromJson(Map<String, dynamic> j) => PassportData(
        valid: (j['valid'] as bool?) ?? false,
        brokenAt: (j['broken_at'] as num?)?.toInt(),
        totalCountries: (j['total_countries'] as num?)?.toInt() ?? 0,
        stamps: (j['stamps'] as num?)?.toInt() ?? 0,
        blocks: [
          for (final b in (j['blocks'] as List?) ?? const [])
            PassportBlock.fromJson(Map<String, dynamic>.from(b as Map)),
        ],
      );
}

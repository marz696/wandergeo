import '../models/country.dart';

/// Data cadangan 12 negara (sama dengan seed di geoquest_schema_v2.sql).
/// Dipakai HANYA saat SQLite masih kosong dan perangkat offline; kondisi
/// normal: data dibaca dari Supabase lalu disimpan di SQLite.
class CountrySeed {
  CountrySeed._();

  static const _a = CountryRegion.asean;

  static const List<Country> all = [
    Country(code: 'ID', name: 'Indonesia', capital: 'Jakarta', language: 'Bahasa Indonesia', lat: -6.2088, lng: 106.8456, region: _a, currency: 'IDR', utcLabel: 'UTC+7 (WIB)', difficulty: 1, status: CountryStatus.terbuka),
    Country(code: 'MY', name: 'Malaysia', capital: 'Kuala Lumpur', language: 'Bahasa Melayu', lat: 3.1390, lng: 101.6869, region: _a, currency: 'MYR', utcLabel: 'UTC+8 (setara WITA)', difficulty: 1, status: CountryStatus.terbuka),
    Country(code: 'SG', name: 'Singapura', capital: 'Singapura', language: 'Inggris, Melayu, Mandarin, Tamil', lat: 1.3521, lng: 103.8198, region: _a, currency: 'SGD', utcLabel: 'UTC+8 (setara WITA)', difficulty: 1, status: CountryStatus.terbuka),
    Country(code: 'TH', name: 'Thailand', capital: 'Bangkok', language: 'Thai', lat: 13.7563, lng: 100.5018, region: _a, currency: 'THB', utcLabel: 'UTC+7 (setara WIB)', difficulty: 2),
    Country(code: 'VN', name: 'Vietnam', capital: 'Hanoi', language: 'Vietnam', lat: 21.0285, lng: 105.8542, region: _a, currency: 'VND', utcLabel: 'UTC+7 (setara WIB)', difficulty: 2),
    Country(code: 'PH', name: 'Filipina', capital: 'Manila', language: 'Filipino, Inggris', lat: 14.5995, lng: 120.9842, region: _a, currency: 'PHP', utcLabel: 'UTC+8 (setara WITA)', difficulty: 2),
    Country(code: 'BN', name: 'Brunei', capital: 'Bandar Seri Begawan', language: 'Bahasa Melayu', lat: 4.9031, lng: 114.9398, region: _a, currency: 'BND', utcLabel: 'UTC+8 (setara WITA)', difficulty: 2),
    Country(code: 'KH', name: 'Kamboja', capital: 'Phnom Penh', language: 'Khmer', lat: 11.5564, lng: 104.9282, region: _a, currency: 'KHR', utcLabel: 'UTC+7 (setara WIB)', difficulty: 3),
    Country(code: 'LA', name: 'Laos', capital: 'Vientiane', language: 'Lao', lat: 17.9757, lng: 102.6331, region: _a, currency: 'LAK', utcLabel: 'UTC+7 (setara WIB)', difficulty: 3),
    Country(code: 'MM', name: 'Myanmar', capital: 'Naypyidaw', language: 'Burma', lat: 19.7633, lng: 96.0785, region: _a, currency: 'MMK', utcLabel: 'UTC+6:30', difficulty: 3),
    Country(code: 'TL', name: 'Timor Leste', capital: 'Dili', language: 'Tetum, Portugis', lat: -8.5569, lng: 125.5603, region: _a, currency: 'USD', utcLabel: 'UTC+9 (setara WIT)', difficulty: 3),
    Country(code: 'GB', name: 'Inggris Raya', capital: 'London', language: 'Inggris', lat: 51.5074, lng: -0.1278, region: CountryRegion.uk, currency: 'GBP', utcLabel: 'UTC+0 / +1 (BST)', difficulty: 2),
  ];
}

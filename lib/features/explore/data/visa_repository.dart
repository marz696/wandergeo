import '../../auth/auth_repository.dart';

/// Hasil pembelian Visa Cepat.
class VisaPurchase {
  const VisaPurchase({required this.price, required this.coins});

  final int price;

  /// Saldo koin setelah pembelian.
  final int coins;
}

class VisaException implements Exception {
  const VisaException(this.message, {this.alreadyOpen = false});

  final String message;

  /// Negara ternyata sudah terbuka (status di layar perlu disegarkan).
  final bool alreadyOpen;

  @override
  String toString() => message;
}

/// Membeli Visa Cepat lewat Edge Function `auth` (action `buy_visa`).
/// Harga dan pemotongan koin sepenuhnya diputuskan server.
class VisaRepository {
  VisaRepository(this._auth);

  final AuthRepository _auth;

  Future<VisaPurchase> buy(String countryCode) async {
    final r = await _auth.authed('buy_visa', {'country_code': countryCode});
    if (!r.ok || r.data == null) {
      throw VisaException(r.message, alreadyOpen: r.status == 409);
    }
    final coins = (r.data!['coins'] as num?)?.toInt();
    final price = (r.data!['price'] as num?)?.toInt() ?? 0;
    if (coins != null) await _auth.updateCoins(coins);
    return VisaPurchase(price: price, coins: coins ?? 0);
  }
}
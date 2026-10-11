class CurrencyInfo {
  const CurrencyInfo(this.code, this.name, this.country);

  final String code;
  final String name;
  final String country;
}

/// Mata uang 11 negara ASEAN + Inggris Raya (Timor Leste memakai USD).
const List<CurrencyInfo> kCurrencies = [
  CurrencyInfo('IDR', 'Rupiah', 'Indonesia'),
  CurrencyInfo('MYR', 'Ringgit', 'Malaysia'),
  CurrencyInfo('SGD', 'Dolar Singapura', 'Singapura'),
  CurrencyInfo('THB', 'Baht', 'Thailand'),
  CurrencyInfo('VND', 'Dong', 'Vietnam'),
  CurrencyInfo('PHP', 'Peso', 'Filipina'),
  CurrencyInfo('BND', 'Dolar Brunei', 'Brunei'),
  CurrencyInfo('KHR', 'Riel', 'Kamboja'),
  CurrencyInfo('LAK', 'Kip', 'Laos'),
  CurrencyInfo('MMK', 'Kyat', 'Myanmar'),
  CurrencyInfo('USD', 'Dolar AS', 'Timor Leste'),
  CurrencyInfo('GBP', 'Poundsterling', 'Inggris Raya'),
];

CurrencyInfo currencyInfo(String code) =>
    kCurrencies.firstWhere((c) => c.code == code,
        orElse: () => CurrencyInfo(code, code, ''));

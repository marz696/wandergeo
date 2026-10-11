import 'package:flutter/services.dart';

/// 1234567.5 -> "1.234.568" ; 0.00023 -> "0,00023" (format Indonesia).
String formatNumber(double v) {
  final abs = v.abs();
  final decimals = abs >= 1000 ? 0 : (abs >= 1 ? 2 : (abs >= 0.01 ? 4 : 6));
  final fixed = v.toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final grouped = parts[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  if (parts.length == 1) return grouped;
  final frac = parts[1].replaceFirst(RegExp(r'0+$'), '');
  return frac.isEmpty ? grouped : '$grouped,$frac';
}

/// "100.000,5" -> 100000.5 ; null bila kosong/tidak valid.
double? parseAmount(String text) =>
    double.tryParse(text.replaceAll('.', '').replaceAll(',', '.'));

/// Menambah titik pemisah ribuan saat mengetik; koma = desimal.
class ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text.replaceAll('.', '');
    final parts = raw.split(',');
    final grouped = parts[0].replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );
    final text =
        parts.length > 1 ? '$grouped,${parts.sublist(1).join()}' : grouped;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

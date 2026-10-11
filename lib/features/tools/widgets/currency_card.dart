import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/data/currencies.dart';
import '../../../core/services/currency_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format_utils.dart';

/// Konversi mata uang antar 12 mata uang ASEAN + Inggris.
class CurrencyCard extends StatefulWidget {
  const CurrencyCard({
    super.key,
    required this.table,
    required this.status,
    required this.onRefresh,
    this.initialTo,
  });

  final RateTable? table;
  final RateStatus status;
  final VoidCallback onRefresh;
  final String? initialTo;

  @override
  State<CurrencyCard> createState() => _CurrencyCardState();
}

class _CurrencyCardState extends State<CurrencyCard> {
  static const _quick = ['SGD', 'THB', 'GBP', 'VND', 'USD'];

  final _amount = TextEditingController(text: '100.000');
  String _from = 'IDR';
  String _to = 'MYR';
  int _swapTurns = 0;

  @override
  void initState() {
    super.initState();
    final t = widget.initialTo;
    if (t == 'IDR') {
      _from = 'MYR';
      _to = 'IDR';
    } else if (t != null) {
      _to = t;
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _swap() {
    HapticFeedback.selectionClick();
    setState(() {
      final f = _from;
      _from = _to;
      _to = f;
      _swapTurns++;
    });
  }

  Future<void> _pick({required bool isFrom}) async {
    final table = widget.table;
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * .7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(isFrom ? 'Dari mata uang' : 'Ke mata uang',
                      style: AppTheme.heading(18)),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  children: [
                    for (final c in kCurrencies)
                      Builder(builder: (_) {
                        final ok = table == null || table.supports(c.code);
                        final current = isFrom ? _from : _to;
                        return ListTile(
                          enabled: ok,
                          leading: Container(
                            width: 48,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.sea,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(c.code,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13)),
                          ),
                          title: Text(c.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(ok
                              ? c.country
                              : '${c.country} · kurs tidak tersedia'),
                          trailing: c.code == current
                              ? const Icon(Icons.check_rounded,
                                  color: AppColors.teal)
                              : null,
                          onTap: () => Navigator.pop(ctx, c.code),
                        );
                      }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        if (picked == _to) {
          _to = _from;
        }
        _from = picked;
      } else {
        if (picked == _from) {
          _from = _to;
        }
        _to = picked;
      }
    });
  }

  String get _footnote {
    final t = widget.table;
    final date = t?.rateDate;
    return switch (widget.status) {
      RateStatus.loading => 'Memuat kurs…',
      RateStatus.fresh =>
        'Kurs ${date ?? ''} · tersimpan untuk dipakai tanpa internet',
      RateStatus.offline =>
        'Offline: memakai kurs tersimpan${date == null ? '' : ' ($date)'}',
      RateStatus.unavailable =>
        'Kurs belum tersedia. Sambungkan internet sekali untuk mengunduhnya.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final table = widget.table;
    final rate = table?.rate(_from, _to);
    final amount = parseAmount(_amount.text);
    final result = (amount != null && rate != null) ? amount * rate : null;
    final loading = widget.status == RateStatus.loading;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Konversi Mata Uang', style: AppTheme.heading(17)),
              ),
              loading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      ),
                    )
                  : IconButton(
                      tooltip: 'Perbarui kurs',
                      onPressed: widget.onRefresh,
                      icon: const Icon(Icons.refresh_rounded,
                          color: AppColors.teal),
                    ),
            ],
          ),
          const SizedBox(height: 4),
          Stack(
            alignment: Alignment.center,
            children: [
              Column(
                children: [
                  _row(
                    label: 'DARI',
                    code: _from,
                    onPick: () => _pick(isFrom: true),
                    value: TextField(
                      controller: _amount,
                      onChanged: (_) => setState(() {}),
                      textAlign: TextAlign.right,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                        ThousandsFormatter(),
                      ],
                      style: AppTheme.heading(24),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: '0',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _row(
                    label: 'KE',
                    code: _to,
                    onPick: () => _pick(isFrom: false),
                    value: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: Align(
                        key: ValueKey('${result?.toStringAsFixed(6)}$_to'),
                        alignment: Alignment.centerRight,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            result == null ? '—' : '≈ ${formatNumber(result)}',
                            style: AppTheme.heading(24, color: AppColors.teal),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Material(
                color: AppColors.ink,
                shape: const CircleBorder(
                    side: BorderSide(color: Colors.white, width: 3)),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _swap,
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: AnimatedRotation(
                      turns: _swapTurns * .5,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutBack,
                      child: const Icon(Icons.swap_vert_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (rate != null)
            Text(
              '1 $_from ≈ ${formatNumber(rate)} $_to',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.deepNavy),
            ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final c in _quick.where((c) => c != _from).take(4))
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(c),
                      selected: _to == c,
                      onSelected: (_) => setState(() => _to = c),
                      selectedColor: AppColors.ink,
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _to == c ? Colors.white : AppColors.deepNavy,
                      ),
                      showCheckmark: false,
                      side: const BorderSide(color: AppColors.border),
                      backgroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(_footnote,
              style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
        ],
      ),
    );
  }

  Widget _row({
    required String label,
    required String code,
    required VoidCallback onPick,
    required Widget value,
  }) {
    final info = currencyInfo(code);
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onPick,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 96, maxWidth: 130),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.muted)),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(code,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800)),
                      const Icon(Icons.arrow_drop_down_rounded),
                    ],
                  ),
                  Text(info.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.muted)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: value),
        ],
      ),
    );
  }
}

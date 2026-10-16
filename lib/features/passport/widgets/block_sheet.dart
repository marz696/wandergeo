import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../models/passport_models.dart';
import '../passport_format.dart';
import 'passport_ui.dart';

/// Detail satu blok di rantai (isi bottom sheet).
class BlockSheet extends StatelessWidget {
  const BlockSheet({required this.block});

  final PassportBlock block;

  @override
  Widget build(BuildContext context) {
    final b = block;
    final ok = b.valid;
    final accent = ok ? AppColors.success : AppColors.error;
    final title = b.isGenesis ? 'Blok genesis' : (b.countryName ?? '-');
    final subtitle = b.isGenesis
        ? 'Awal rantai · Blok #0'
        : '${(b.capital ?? '').isEmpty ? '' : '${b.capital} · '}Blok #${b.index}';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 10, 22, 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  if (b.isGenesis)
                    Container(
                      width: 48,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.sea,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.public_rounded,
                          color: AppColors.teal, size: 20),
                    )
                  else
                    PassportFlag(url: b.flagUrl, size: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: AppTheme.heading(18)),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                              color: AppColors.muted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: accent.withOpacity(.10),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      ok ? Icons.verified_rounded : Icons.gpp_bad_rounded,
                      size: 16,
                      color: accent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      ok
                          ? 'Hash cocok dengan isi blok'
                          : 'Hash tidak cocok: blok ini diubah',
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (!b.isGenesis)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: _InfoTile(label: 'Skor negara', value: '${b.score}'),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 5,
                      child: _InfoTile(
                          label: 'Waktu', value: passportDateTime(b.timestamp)),
                    ),
                  ],
                )
              else
                _InfoTile(label: 'Waktu', value: passportDateTime(b.timestamp)),
              const SizedBox(height: 10),
              _InfoTile(
                label: 'Hash sebelumnya',
                value: b.previousHash.isEmpty ? '-' : b.previousHash,
                mono: true,
                copyable: b.previousHash.isNotEmpty,
              ),
              const SizedBox(height: 10),
              _InfoTile(
                label: 'Hash blok ini',
                value: b.hash,
                mono: true,
                copyable: b.hash.isNotEmpty,
              ),
              const SizedBox(height: 10),
              _InfoTile(
                label: 'Nonce · proof-of-work (awalan "00")',
                value: '${b.nonce}',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatefulWidget {
  const _InfoTile({
    required this.label,
    required this.value,
    this.mono = false,
    this.copyable = false,
  });

  final String label;
  final String value;
  final bool mono;
  final bool copyable;

  @override
  State<_InfoTile> createState() => _InfoTileState();
}

class _InfoTileState extends State<_InfoTile> {
  bool _copied = false;

  Future<void> _copy() async {
    HapticFeedback.selectionClick();
    await Clipboard.setData(ClipboardData(text: widget.value));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.label,
                    style:
                        const TextStyle(color: AppColors.hint, fontSize: 12)),
                const SizedBox(height: 3),
                SelectableText(
                  widget.value,
                  style: TextStyle(
                    color: AppColors.ink,
                    fontFamily: widget.mono ? 'monospace' : null,
                    fontSize: widget.mono ? 12 : 14,
                    fontWeight: widget.mono ? FontWeight.w400 : FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (widget.copyable)
            IconButton(
              onPressed: _copy,
              tooltip: 'Salin',
              visualDensity: VisualDensity.compact,
              icon: Icon(
                _copied ? Icons.check_rounded : Icons.copy_rounded,
                size: 18,
                color: _copied ? AppColors.success : AppColors.hint,
              ),
            )
          else
            const SizedBox(width: 6),
        ],
      ),
    );
  }
}


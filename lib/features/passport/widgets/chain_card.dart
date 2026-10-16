import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/passport_models.dart';
import '../passport_format.dart';
import 'passport_ui.dart';

class ChainCard extends StatelessWidget {
  const ChainCard({required this.blocks, required this.onTap});

  final List<PassportBlock> blocks;
  final ValueChanged<PassportBlock> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: passportCardShadow,
      ),
      child: Column(
        children: [
          for (var i = 0; i < blocks.length; i++)
            _ChainRow(
              block: blocks[i],
              last: i == blocks.length - 1,
              onTap: () => onTap(blocks[i]),
            ),
        ],
      ),
    );
  }
}

class _ChainRow extends StatelessWidget {
  const _ChainRow({
    required this.block,
    required this.last,
    required this.onTap,
  });

  final PassportBlock block;
  final bool last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ok = block.valid;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 38,
            child: Column(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: ok ? AppColors.sea : AppColors.error.withOpacity(.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: block.isGenesis
                      ? Icon(Icons.public_rounded,
                          size: 19, color: ok ? AppColors.teal : AppColors.error)
                      : Text(
                          '#${block.index}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: ok ? AppColors.teal : AppColors.error,
                          ),
                        ),
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: ok
                            ? AppColors.border
                            : AppColors.error.withOpacity(.35),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: Padding(
                padding: EdgeInsets.only(bottom: last ? 0 : 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            block.isGenesis
                                ? 'Blok genesis'
                                : (block.countryName ?? '-'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                              fontSize: 14.5,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            passportShortHash(block.hash),
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: AppColors.hint,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      ok ? Icons.link_rounded : Icons.link_off_rounded,
                      color: ok ? AppColors.hint : AppColors.error,
                      size: 19,
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


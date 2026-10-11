import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.size = 44,
    this.iconColor = AppColors.ink,
    this.elevated = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final double size;
  final Color iconColor;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Material(
        color: Colors.white,
        elevation: elevated ? 4 : 0,
        shadowColor: AppColors.ink.withOpacity(.25),
        shape: CircleBorder(
          side: BorderSide(color: elevated ? Colors.transparent : AppColors.border),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, size: 22, color: iconColor),
          ),
        ),
      ),
    );
  }
}

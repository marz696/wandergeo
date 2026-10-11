import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/round_icon_button.dart';

/// Kontrol di sisi kanan peta: zoom, lokasiku, kompas (sensor magnetometer).
class MapControls extends StatelessWidget {
  const MapControls({
    super.key,
    required this.headings,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onMyLocation,
  });

  final Stream<double?> headings;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onMyLocation;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.white,
          elevation: 4,
          shadowColor: AppColors.ink.withOpacity(.25),
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _btn(Icons.add_rounded, 'Perbesar', onZoomIn),
              const Divider(height: 1, indent: 10, endIndent: 10),
              _btn(Icons.remove_rounded, 'Perkecil', onZoomOut),
            ],
          ),
        ),
        const SizedBox(height: 10),
        RoundIconButton(
          icon: Icons.my_location_rounded,
          label: 'Lokasiku',
          iconColor: const Color(0xFF2F80ED),
          onTap: onMyLocation,
        ),
        const SizedBox(height: 10),
        StreamBuilder<double?>(
          stream: headings,
          builder: (context, snap) {
            final heading = snap.data ?? 0;
            return Semantics(
              label: 'Kompas, arah ${heading.round()} derajat',
              child: Material(
                color: Colors.white,
                elevation: 4,
                shadowColor: AppColors.ink.withOpacity(.25),
                shape: const CircleBorder(),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Transform.rotate(
                    angle: -heading * math.pi / 180,
                    child: const Icon(
                      Icons.navigation_rounded,
                      color: AppColors.error,
                      size: 24,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _btn(IconData icon, String label, VoidCallback onTap) => Tooltip(
        message: label,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, color: AppColors.ink),
          ),
        ),
      );
}

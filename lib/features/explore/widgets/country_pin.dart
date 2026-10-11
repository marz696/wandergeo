import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/country.dart';

/// Pin berbentuk tetesan untuk Marker flutter_map.
/// Ukuran Marker harus 64 x 112: ujung pin tepat di tengah kotak (= koordinat).
class CountryPin extends StatelessWidget {
  const CountryPin({
    super.key,
    required this.country,
    required this.selected,
    required this.dimmed,
    required this.pulse,
    required this.onTap,
    this.bubble,
  });

  static const double width = 64;
  static const double height = 112;

  final Country country;
  final bool selected;
  final bool dimmed;
  final Animation<double> pulse;
  final VoidCallback onTap;
  final String? bubble; // teks gelembung di atas pin (saat terpilih)

  Color get _color => switch (country.status) {
        CountryStatus.selesai => AppColors.success,
        CountryStatus.terbuka => AppColors.teal,
        CountryStatus.terkunci => const Color(0xFF8FA3B1),
      };

  Widget get _content => switch (country.status) {
        CountryStatus.selesai =>
          const Icon(Icons.check_rounded, size: 18, color: Colors.white),
        CountryStatus.terbuka => Text(
            country.code,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        CountryStatus.terkunci =>
          const Icon(Icons.lock_rounded, size: 15, color: Colors.white),
      };

  @override
  Widget build(BuildContext context) {
    final open = country.status == CountryStatus.terbuka;
    return Semantics(
      button: true,
      label: '${country.name}, ${country.statusLabel}',
      child: AnimatedOpacity(
        opacity: dimmed ? .3 : 1,
        duration: const Duration(milliseconds: 220),
        child: SizedBox(
          width: width,
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Bayangan di ujung pin.
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: Container(
                      width: 18,
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(.3),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Cincin denyut untuk negara terbuka.
              if (open)
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: pulse,
                      builder: (_, __) {
                        final t = pulse.value;
                        return Center(
                          child: Container(
                            width: 34 + 24 * t,
                            height: 12 + 9 * t,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.gold.withOpacity((1 - t) * .9),
                                width: 2,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              // Badan pin: kotak 48 dengan sisi bawah = ujung pin.
              Positioned(
                left: 8,
                top: 8,
                width: 48,
                height: 48,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onTap,
                  child: AnimatedScale(
                    scale: selected ? 1.3 : 1,
                    alignment: Alignment.bottomCenter,
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutBack,
                    child: Center(
                      child: Transform.rotate(
                        angle: -math.pi / 4,
                        child: Container(
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _color,
                            border: Border.all(
                              color: selected ? AppColors.gold : Colors.white,
                              width: 3,
                            ),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(17),
                              topRight: Radius.circular(17),
                              bottomRight: Radius.circular(17),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(.25),
                                blurRadius: 8,
                                offset: const Offset(2, 3),
                              ),
                            ],
                          ),
                          child: Transform.rotate(
                            angle: math.pi / 4,
                            child: _content,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (bubble != null)
                Positioned(
                  left: -90,
                  right: -90,
                  top: -36,
                  child: IgnorePointer(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.ink,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(.3),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Text(
                          bubble!,
                          maxLines: 1,
                          softWrap: false,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Titik posisi pengguna (biru + denyut). Untuk Marker 44 x 44.
class UserDot extends StatelessWidget {
  const UserDot({super.key, required this.pulse});

  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: pulse,
            builder: (_, __) => Container(
              width: 16 + 28 * pulse.value,
              height: 16 + 28 * pulse.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2F80ED)
                    .withOpacity((1 - pulse.value) * .3),
              ),
            ),
          ),
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF2F80ED),
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(.3), blurRadius: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

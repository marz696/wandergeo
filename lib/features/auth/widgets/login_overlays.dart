import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../login_controller.dart';

/// Layar "Verifikasi identitas": ikon biometrik berdenyut + tombol Batal.
class BiometricOverlay extends StatefulWidget {
  const BiometricOverlay({
    super.key,
    required this.visible,
    required this.kind,
    required this.onCancel,
  });

  final bool visible;
  final BiometricKind kind;
  final VoidCallback onCancel;

  @override
  State<BiometricOverlay> createState() => _BiometricOverlayState();
}

class _BiometricOverlayState extends State<BiometricOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void initState() {
    super.initState();
    if (widget.visible) _pulse.repeat();
  }

  @override
  void didUpdateWidget(BiometricOverlay old) {
    super.didUpdateWidget(old);
    if (widget.visible && !_pulse.isAnimating) {
      _pulse.repeat();
    } else if (!widget.visible) {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fp = widget.kind == BiometricKind.fingerprint;
    return IgnorePointer(
      ignoring: !widget.visible,
      child: AnimatedOpacity(
        opacity: widget.visible ? 1 : 0,
        duration: const Duration(milliseconds: 400),
        child: ColoredBox(
          color: Colors.white,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 96,
                    height: 96,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _pulse,
                          builder: (_, __) => Opacity(
                            opacity: (1 - _pulse.value) * .8,
                            child: Transform.scale(
                              scale: 1 + .7 * _pulse.value,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.teal, width: 2),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Icon(
                          fp ? Icons.fingerprint : Icons.face_outlined,
                          size: 56,
                          color: AppColors.teal,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text('Verifikasi identitas', style: AppTheme.heading(20)),
                  const SizedBox(height: 14),
                  Text(
                    fp ? 'Sentuh sensor sidik jari' : 'Pindai wajahmu',
                    style: const TextStyle(fontSize: 14, color: AppColors.muted),
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: widget.onCancel,
                    child: const Text(
                      'Batal',
                      style: TextStyle(
                        color: AppColors.teal,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

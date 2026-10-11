import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Sementara. Ganti dengan MainShell (bottom navigation 5 menu) nantinya.
class HomePlaceholderPage extends StatelessWidget {
  const HomePlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text('Eksplorasi (menyusul)', style: AppTheme.heading(22)),
      ),
    );
  }
}

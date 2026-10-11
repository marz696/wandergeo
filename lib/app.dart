import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'routes.dart';

class WanderGeoApp extends StatelessWidget {
  const WanderGeoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WanderGeo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRoutes.onGenerate,
    );
  }
}

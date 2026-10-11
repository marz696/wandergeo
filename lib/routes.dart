import 'package:flutter/material.dart';

import 'features/auth/login_page.dart';
import 'features/home/home_placeholder_page.dart';
import 'features/splash/splash_page.dart';

class AppRoutes {
  AppRoutes._();

  static const splash = '/';
  static const login = '/login';
  static const home = '/home';

  static Route<dynamic> onGenerate(RouteSettings settings) {
    final Widget page;
    if (settings.name == login) {
      page = const LoginPage();
    } else if (settings.name == home) {
      page = const HomePlaceholderPage();
    } else {
      page = const SplashPage();
    }
    return PageRouteBuilder<void>(
      settings: settings,
      transitionDuration: const Duration(milliseconds: 600),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    );
  }
}

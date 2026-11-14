import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'features/library/presentation/screens/library_screen.dart';
import 'features/reader/presentation/screens/reader_screen.dart';
import 'features/settings/ai_settings_screen.dart';
import 'features/splash/presentation/screens/splash_screen.dart';
import 'features/stats/presentation/screens/reading_stats_screen.dart';

final _router = GoRouter(
  initialLocation: '/splash',
  errorBuilder: (context, state) => const LibraryScreen(),
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/library',
      builder: (context, state) => const LibraryScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const AiSettingsScreen(),
    ),
    GoRoute(
      path: '/stats',
      builder: (context, state) => const ReadingStatsScreen(),
    ),
    GoRoute(
      path: '/reader/:bookId',
      builder: (context, state) {
        final bookId = state.pathParameters['bookId'] ?? '';
        return ReaderScreen(bookId: bookId);
      },
    ),
  ],
);

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConstants.appName,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}

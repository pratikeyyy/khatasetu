import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/navigation/app_router.dart';
import 'providers/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: KhataSetuApp()));
}

class KhataSetuApp extends ConsumerWidget {
  const KhataSetuApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // If a logged-in session dies later (e.g. the token expires and a
    // background validation gets a 401), send the user back to login
    // from wherever they are. Only fires on a true -> false flip, so
    // the fresh logged-out state at startup never triggers it.
    ref.listen<AuthState>(authProvider, (previous, next) {
      final wasAuthenticated = previous?.isAuthenticated ?? false;
      if (wasAuthenticated && !next.isAuthenticated) {
        appRouter.go("/login");
      }
    });

    return MaterialApp.router(
      title: "KhataSetu",
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      routerConfig: appRouter,
    );
  }
}

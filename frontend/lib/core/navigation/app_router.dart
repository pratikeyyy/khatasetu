import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../screens/splash_screen.dart';
import '../../screens/onboarding_screen.dart';
import '../../screens/login_screen.dart';
import '../../screens/register_screen.dart';
import '../../screens/home_screen.dart';
import '../../screens/scanner_screen.dart';
import '../../screens/ocr_review_screen.dart';
import '../../screens/customers_screen.dart';
import '../../screens/customer_detail_screen.dart';
import '../../screens/add_transaction_screen.dart';
import '../../screens/ledger_screen.dart';
import '../../screens/dashboard_screen.dart';
import '../../screens/profile_screen.dart';
import '../../screens/main_shell.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _homeNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _customersNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _ledgerNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _analyticsNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _settingsNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: "/",
  routes: [
    GoRoute(
      path: "/",
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: "/onboarding",
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: "/login",
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: "/register",
      builder: (context, state) => const RegisterScreen(),
    ),

    // Stateful Nested Shell for Bottom Navigation
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return MainShell(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          navigatorKey: _homeNavigatorKey,
          routes: [
            GoRoute(
              path: "/home",
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _customersNavigatorKey,
          routes: [
            GoRoute(
              path: "/customers",
              builder: (context, state) => const CustomersScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _ledgerNavigatorKey,
          routes: [
            GoRoute(
              path: "/ledger",
              builder: (context, state) => const LedgerScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _analyticsNavigatorKey,
          routes: [
            GoRoute(
              path: "/analytics",
              builder: (context, state) => const DashboardScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _settingsNavigatorKey,
          routes: [
            GoRoute(
              path: "/settings",
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),
      ],
    ),

    // Modal / Direct Screens
    GoRoute(
      path: "/scanner",
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ScannerScreen(),
    ),
    GoRoute(
      path: "/scan-review/:scanId",
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final scanId = int.tryParse(state.pathParameters['scanId'] ?? '') ?? 0;
        return OcrReviewScreen(scanId: scanId);
      },
    ),
    GoRoute(
      path: "/customer/:id",
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
        return CustomerDetailScreen(customerId: id);
      },
    ),
    GoRoute(
      path: "/add-transaction",
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final customerIdStr = state.uri.queryParameters['customerId'];
        final customerId = customerIdStr != null ? int.tryParse(customerIdStr) : null;
        return AddTransactionScreen(prefilledCustomerId: customerId);
      },
    ),
  ],
);

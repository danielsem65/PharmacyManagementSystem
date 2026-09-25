import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/auth_controller.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/home/presentation/home_shell.dart';
import '../features/invoice_tracker/presentation/invoice_tracker_screen.dart';

// Forces GoRouter to re-evaluate redirects when auth state changes.
final ValueNotifier<int> _routerRefresh = ValueNotifier<int>(0);

const List<String> _publicPaths = ['/login', '/tracker'];

final routerProvider = Provider<GoRouter>((ref) {
  ref.listen(authControllerProvider, (_, __) => _routerRefresh.value++);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: _routerRefresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final loggedIn = auth.status == AuthStatus.authenticated;
      final goingToLogin = state.matchedLocation == '/login';

      if (!loggedIn && !_publicPaths.contains(state.matchedLocation)) {
        return '/login';
      }
      if (loggedIn && goingToLogin) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/tracker',
        builder: (context, state) => const InvoiceTrackerScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeShell(),
      ),
    ],
  );
});
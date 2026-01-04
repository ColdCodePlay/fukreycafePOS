import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'features/auth/login_screen.dart';
import 'features/home_screen.dart';
import 'features/pos/pos_screen.dart';
import 'features/admin/admin_dashboard.dart';
import 'repositories/auth_repository.dart';
import 'core/navigator_key.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  // We desire to refresh when the profile loads/changes too, not just auth state.
  // But GoRouter refreshListenable expects a Listenable (Stream is adaptable).
  // Ideally, we should unify this state. For now, we'll trigger simple redirects 
  // and rely on the UI to handle "loading" profile states if needed, 
  // or use a combined stream.
  
  // NOTE: Simply listening to authStateChanges is fast but doesn't have role info immediately.
  // We might need to listen to userProfileProvider.stream too? 
  // A simpler approach for this scale: relying on auth state for basic login guard,
  // and then inside the screens or a secondary guard, redirect if role mismatch.
  // HOWEVER, simpler for a rigid POS is to guard at the router level.
  
  return GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: '/',
    refreshListenable: GoRouterRefreshStream(authRepo.authStateChanges),
    redirect: (context, state) async {
      final isLoggedIn = authRepo.currentUser != null;
      final isLoggingIn = state.matchedLocation == '/login';

      if (!isLoggedIn) {
        return isLoggingIn ? null : '/login';
      }

      // User IS logged in.
      // If they are on Login page, send them to home (which will decide where else to go)
      if (isLoggingIn) {
         return '/';
      }

      // We can do Role checks here by reading the repo directly if we want synchronous-like feel
      // or we accept that "/" might be a "Loader/Dispatcher" page.
      
      return null;
    },
    routes: [

      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/pos',
        builder: (context, state) => const PosScreen(),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminDashboardScreen(),
      ),
    ],
  );
});

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
      (dynamic _) => notifyListeners(),
    );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}


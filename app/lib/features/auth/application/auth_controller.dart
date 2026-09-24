import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/app_user.dart';
import '../data/supabase_auth_gateway.dart';

enum AuthStatus {
  checking,
  unauthenticated,
  authenticating,
  authenticated,
  error,
}

/// The provider of the authenticated user + permissions for the whole app.
final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) {
    final gateway = ref.watch(authGatewayProvider);
    final controller = AuthController(gateway);
    controller.init();
    return controller;
  },
);

final authGatewayProvider = Provider<AuthGateway>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseAuthGateway(client);
});

class AuthState {
  const AuthState({
    required this.status,
    this.user,
    this.error,
  });

  const AuthState.checking() : this(status: AuthStatus.checking);

  final AuthStatus status;
  final AppUser? user;
  final String? error;

  bool get isAuthenticated => status == AuthStatus.authenticated;
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._gateway) : super(const AuthState.checking());

  final AuthGateway _gateway;

  Future<void> init() async {
    try {
      final user = await _gateway.currentUser();
      state = user != null
          ? AuthState(status: AuthStatus.authenticated, user: user)
          : const AuthState(status: AuthStatus.unauthenticated);
    } catch (e) {
      state = AuthState(status: AuthStatus.error, error: e.toString());
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    state = AuthState(status: AuthStatus.authenticating);
    try {
      final user = await _gateway.signIn(email: email, password: password);
      state = user != null
          ? AuthState(status: AuthStatus.authenticated, user: user)
          : const AuthState(status: AuthStatus.unauthenticated);
    } catch (e) {
      state = AuthState(status: AuthStatus.error, error: 'Invalid email or password.');
    }
  }

  Future<void> signOut() async {
    try {
      await _gateway.signOut();
    } finally {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }
}
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/app_user.dart';

/// The Supabase client. Overridden in main() with the initialized instance.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  throw UnimplementedError('supabaseClientProvider must be overridden');
});

/// Abstraction over the auth backend so controllers stay testable.
abstract interface class AuthGateway {
  Future<AppUser?> currentUser();
  Future<AppUser?> signIn({required String email, required String password});
  Future<void> signOut();
}

class SupabaseAuthGateway implements AuthGateway {
  SupabaseAuthGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<AppUser?> currentUser() async {
    final session = _client.auth.currentSession;
    if (session == null) return null;
    return _loadContext(session.user.id);
  }

  @override
  Future<AppUser?> signIn({required String email, required String password}) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    final session = response.session;
    if (session == null) return null;
    return _loadContext(session.user.id);
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  Future<AppUser?> _loadContext(String userId) async {
    final data = await _client.rpc('login_context');
    final map = (data as Map).cast<String, dynamic>();
    return AppUser.fromContext(map);
  }
}
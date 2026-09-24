import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pharmacy_app/app.dart';
import 'package:pharmacy_app/features/auth/application/auth_controller.dart';
import 'package:pharmacy_app/features/auth/data/supabase_auth_gateway.dart';
import 'package:pharmacy_app/models/app_user.dart';

class _SignedOutGateway implements AuthGateway {
  @override
  Future<AppUser?> currentUser() async => null;

  @override
  Future<AppUser?> signIn({required String email, required String password}) async => null;

  @override
  Future<void> signOut() async {}
}

void main() {
  testWidgets('unauthenticated users are redirected to login', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authGatewayProvider.overrideWithValue(_SignedOutGateway()),
        ],
        child: const PharmacyApp(),
      ),
    );

    expect(find.text('Sign in to your account'), findsOneWidget);

    await tester.pump();
    expect(find.text('Sign in to your account'), findsOneWidget);
  });
}
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pharmacy_app/features/auth/application/auth_controller.dart';
import 'package:pharmacy_app/features/auth/data/supabase_auth_gateway.dart';
import 'package:pharmacy_app/features/home/presentation/home_shell.dart';
import 'package:pharmacy_app/models/app_user.dart';

AppUser _cashier() => AppUser.fromContext({
      'profile': {'id': 'c1', 'full_name': 'Cashier', 'role': 'cashier'},
      'permissions': ['dashboard.view', 'sales.create', 'invoice.print'],
    });

class _FakeGateway implements AuthGateway {
  _FakeGateway(this.user);
  AppUser? user;

  @override
  Future<AppUser?> currentUser() async => user;

  @override
  Future<AppUser?> signIn({required String email, required String password}) async =>
      throw UnimplementedError();

  @override
  Future<void> signOut() async {}
}

void main() {
  Widget buildApp() {
    return ProviderScope(
      overrides: [
        authGatewayProvider.overrideWithValue(_FakeGateway(_cashier())),
      ],
      child: const MaterialApp(home: HomeShell()),
    );
  }

  testWidgets('HomeShell only shows permission-gated navigation items', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pump();

    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Point of Sale'), findsWidgets);
    expect(find.text('Products'), findsNothing);
    expect(find.text('Reports'), findsNothing);
    expect(find.text('Settings'), findsNothing);
  });
}
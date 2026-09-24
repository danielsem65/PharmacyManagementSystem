import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_app/models/app_user.dart';

void main() {
  group('AppUser.fromContext', () {
    test('parses profile, permissions and settings', () {
      final user = AppUser.fromContext({
        'profile': {
          'id': 'user-1',
          'full_name': 'Ama Boateng',
          'role': 'cashier',
          'branch_id': 'branch-1',
          'email': 'ama@pharmacy.com',
        },
        'permissions': ['sales.create', 'customer.manage', 'invoice.print'],
        'settings': {'currency': 'GHS', 'invoice_prefix': 'INV-'},
      });

      expect(user.id, 'user-1');
      expect(user.fullName, 'Ama Boateng');
      expect(user.role, 'cashier');
      expect(user.branchId, 'branch-1');
      expect(user.can('sales.create'), isTrue);
      expect(user.can('inventory.adjust'), isFalse);
      expect(user.settings['currency'], 'GHS');
      expect(user.isOwner, isFalse);
      expect(user.isManager, isFalse);
    });

    test('owner role is manager-equivalent', () {
      final user = AppUser.fromContext({
        'profile': {'id': 'owner', 'full_name': 'Owner', 'role': 'owner'},
        'permissions': <String>[],
      });
      expect(user.isOwner, isTrue);
      expect(user.isManager, isTrue);
    });

    test('tolerates missing optional data', () {
      final user = AppUser.fromContext({
        'profile': {'id': 'x', 'full_name': 'X', 'role': 'staff'},
        'permissions': null,
        'settings': null,
      });
      expect(user.permissions, isEmpty);
      expect(user.settings, isEmpty);
      expect(user.branchId, '');
    });
  });

  group('Permission gating', () {
    test('cashier cannot adjust inventory or void sales', () {
      final cashier = AppUser.fromContext({
        'profile': {'id': 'c', 'full_name': 'Cashier', 'role': 'cashier'},
        'permissions': ['sales.create', 'customer.manage', 'invoice.print'],
      });
      expect(cashier.can('sales.create'), isTrue);
      expect(cashier.can('inventory.adjust'), isFalse);
      expect(cashier.can('sales.void'), isFalse);
      expect(cashier.can('report.financial'), isFalse);
    });
  });
}
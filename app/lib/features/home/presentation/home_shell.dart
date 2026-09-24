import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/permissions.dart';
import '../../../features/auth/application/auth_controller.dart';
import '../../../models/app_user.dart';
import '../../../shared/widgets/placeholder_page.dart';

class _NavItem {
  const _NavItem(this.title, this.icon, this.permission, this.page);

  final String title;
  final IconData icon;
  final String permission;
  final Widget page;
}

final List<_NavItem> _allItems = [
  _NavItem('Dashboard', Icons.dashboard_outlined, Permissions.dashboardView,
      const PlaceholderPage(title: 'Dashboard', icon: Icons.dashboard_outlined, phase: 'Phase 10')),
  _NavItem('Point of Sale', Icons.point_of_sale_outlined, Permissions.salesCreate,
      const PlaceholderPage(title: 'Point of Sale', icon: Icons.point_of_sale_outlined, phase: 'Phase 4')),
  _NavItem('Products', Icons.medication_outlined, Permissions.productView,
      const PlaceholderPage(title: 'Products', icon: Icons.medication_outlined, phase: 'Phase 3')),
  _NavItem('Inventory', Icons.inventory_2_outlined, Permissions.inventoryView,
      const PlaceholderPage(title: 'Inventory', icon: Icons.inventory_2_outlined, phase: 'Phase 3')),
  _NavItem('Sales', Icons.receipt_long_outlined, Permissions.salesView,
      const PlaceholderPage(title: 'Sales', icon: Icons.receipt_long_outlined, phase: 'Phase 4')),
  _NavItem('Invoices', Icons.request_quote_outlined, Permissions.invoiceView,
      const PlaceholderPage(title: 'Invoices', icon: Icons.request_quote_outlined, phase: 'Phase 5')),
  _NavItem('Customers', Icons.people_outline, Permissions.customerView,
      const PlaceholderPage(title: 'Customers', icon: Icons.people_outline, phase: 'Phase 6')),
  _NavItem('Suppliers', Icons.business_outlined, Permissions.supplierView,
      const PlaceholderPage(title: 'Suppliers', icon: Icons.business_outlined, phase: 'Phase 6')),
  _NavItem('Purchases', Icons.shopping_cart_outlined, Permissions.purchaseView,
      const PlaceholderPage(title: 'Purchases', icon: Icons.shopping_cart_outlined, phase: 'Phase 7')),
  _NavItem('Returns', Icons.assignment_return_outlined, Permissions.salesRefund,
      const PlaceholderPage(title: 'Returns', icon: Icons.assignment_return_outlined, phase: 'Phase 4')),
  _NavItem('Expenses', Icons.payments_outlined, Permissions.expenseView,
      const PlaceholderPage(title: 'Expenses', icon: Icons.payments_outlined, phase: 'Phase 9')),
  _NavItem('Employees', Icons.badge_outlined, Permissions.employeeView,
      const PlaceholderPage(title: 'Employees', icon: Icons.badge_outlined, phase: 'Phase 8')),
  _NavItem('Attendance', Icons.schedule_outlined, Permissions.attendanceSelf,
      const PlaceholderPage(title: 'Attendance', icon: Icons.schedule_outlined, phase: 'Phase 8')),
  _NavItem('Reports', Icons.assessment_outlined, Permissions.reportView,
      const PlaceholderPage(title: 'Reports', icon: Icons.assessment_outlined, phase: 'Phase 10')),
  _NavItem('Notifications', Icons.notifications_outlined, Permissions.notificationView,
      const PlaceholderPage(title: 'Notifications', icon: Icons.notifications_outlined, phase: 'Phase 11')),
  _NavItem('Audit Log', Icons.history_outlined, Permissions.auditView,
      const PlaceholderPage(title: 'Audit Log', icon: Icons.history_outlined, phase: 'Phase 11')),
  _NavItem('Settings', Icons.settings_outlined, Permissions.settingsManage,
      const PlaceholderPage(title: 'Settings', icon: Icons.settings_outlined, phase: 'Phase 12')),
];

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _selectedIndex = 0;

  List<_NavItem> _allowedItems(AppUser user) {
    return _allItems.where((item) => user.can(item.permission)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.user;
    if (user == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    final items = _allowedItems(user);
    if (_selectedIndex >= items.length) _selectedIndex = 0;

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (i) => setState(() => _selectedIndex = i),
            labelType: NavigationRailLabelType.all,
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Icon(Icons.local_pharmacy, size: 32, color: Color(0xFF0E7490)),
            ),
            destinations: [for (final item in items) NavigationRailDestination(icon: Icon(item.icon), label: Text(item.title))],
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: IconButton(
                  tooltip: 'Sign out',
                  icon: const Icon(Icons.logout),
                  onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
                ),
              ),
            ),
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: [for (final item in items) item.page],
            ),
          ),
        ],
      ),
    );
  }
}
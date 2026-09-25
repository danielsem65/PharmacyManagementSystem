import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_app/features/invoice_tracker/application/invoice_tracker_controller.dart';
import 'package:pharmacy_app/features/invoice_tracker/domain/invoice_entry.dart';
import 'package:pharmacy_app/features/invoice_tracker/presentation/invoice_tracker_screen.dart';

class InMemoryPersistence implements InvoicePersistence {
  InMemoryPersistence(List<InvoiceEntry>? initial) : _data = initial;

  List<InvoiceEntry>? _data;

  @override
  Future<List<InvoiceEntry>?> load() async => _data;

  @override
  Future<void> save(List<InvoiceEntry> invoices) async {
    _data = List.of(invoices);
  }
}

Widget _harness(InvoicePersistence persistence) {
  return ProviderScope(
    overrides: [
      invoicePersistenceProvider.overrideWithValue(persistence),
    ],
    child: const MaterialApp(home: InvoiceTrackerScreen()),
  );
}

InvoiceEntry _invoice({
  required String id,
  required String number,
  String client = 'ABC Corp',
  int amountCents = 100000,
  double taxRatePercent = 8,
  int amountPaidCents = 0,
  DateTime? dueDate,
}) {
  return InvoiceEntry(
    id: id,
    invoiceNumber: number,
    client: client,
    description: 'Consulting',
    invoiceDate: DateTime(2026, 1, 15),
    dueDate: dueDate ?? DateTime(2026, 2, 15),
    amountCents: amountCents,
    taxRatePercent: taxRatePercent,
    amountPaidCents: amountPaidCents,
  );
}

void main() {
  testWidgets('renders the Excel-style summary block and invoice table', (tester) async {
    final persistence = InMemoryPersistence([
      _invoice(id: '1', number: 'INV-001', amountCents: 100000, dueDate: DateTime(2026, 1, 20)),
      _invoice(
        id: '2',
        number: 'INV-002',
        amountCents: 50000,
        taxRatePercent: 0,
        amountPaidCents: 50000,
        dueDate: DateTime(2026, 4, 1),
      ),
    ]);

    await tester.pumpWidget(_harness(persistence));
    await tester.pumpAndSettle();

    expect(find.text('Total Invoiced'), findsOneWidget);
    expect(find.text('158,000.00'), findsWidgets); // sum of totals
    expect(find.text('8,000.00'), findsWidgets); // tax collected
    expect(find.text('50,000.00'), findsWidgets); // total paid
    expect(find.text('108,000.00'), findsWidgets); // outstanding

    expect(find.text('Invoices Logged'), findsOneWidget);
    expect(find.text('2'), findsWidgets);

    expect(find.text('INV-001'), findsOneWidget);
    expect(find.text('INV-002'), findsOneWidget);
    expect(find.text('Overdue'), findsOneWidget);
  });

  testWidgets('shows empty state then adds an invoice through the form', (tester) async {
    final persistence = InMemoryPersistence(const []);

    await tester.pumpWidget(_harness(persistence));
    await tester.pumpAndSettle();

    expect(find.text('No invoices yet.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('add_invoice')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('invoice_number')), 'INV-005');
    await tester.enterText(find.byKey(const Key('invoice_client')), 'ACME Corp');
    await tester.enterText(find.byKey(const Key('invoice_amount')), '1000');
    await tester.enterText(find.byKey(const Key('invoice_tax_rate')), '8');

    await tester.tap(find.byKey(const Key('invoice_save')));
    await tester.pumpAndSettle();

    expect(find.text('No invoices yet.'), findsNothing);
    expect(find.text('INV-005'), findsOneWidget);
    expect(find.text('ACME Corp'), findsOneWidget);
    // Total invoiced updated to 1080.00 + tax 80.00
    expect(find.text('1,080.00'), findsWidgets);
    expect(find.text('1'), findsWidgets); // Invoices Logged count
  });

  testWidgets('marks an invoice paid when balance reaches zero', (tester) async {
    final persistence = InMemoryPersistence([
      _invoice(
        id: '1',
        number: 'INV-010',
        amountCents: 100000,
        amountPaidCents: 108000,
        dueDate: DateTime(2026, 1, 20),
      ),
    ]);

    await tester.pumpWidget(_harness(persistence));
    await tester.pumpAndSettle();

    expect(find.text('Paid'), findsOneWidget);
    expect(find.text('0.00'), findsWidgets); // balance
  });
}
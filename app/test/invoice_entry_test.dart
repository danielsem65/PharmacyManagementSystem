import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_app/features/invoice_tracker/domain/invoice_entry.dart';

InvoiceEntry _invoice({
  String id = '1',
  int amountCents = 100000,
  double taxRatePercent = 8,
  int amountPaidCents = 0,
  DateTime? dueDate,
}) {
  const today = DateTime(2026, 1, 15);
  return InvoiceEntry(
    id: id,
    invoiceNumber: 'INV-001',
    client: 'ABC Corp',
    description: 'Web design services',
    invoiceDate: today,
    dueDate: dueDate ?? DateTime(2026, 2, 15),
    amountCents: amountCents,
    taxRatePercent: taxRatePercent,
    amountPaidCents: amountPaidCents,
  );
}

void main() {
  group('Auto-calculated columns (match the Excel formulas)', () {
    test('tax = amount x rate, total = amount + tax, balance = total - paid', () {
      final invoice = _invoice(
        amountCents: 100000, // 1000.00
        taxRatePercent: 12,
        amountPaidCents: 112000, // 1120.00
      );

      expect(invoice.taxCents, 12000); // H column
      expect(invoice.totalCents, 112000); // I column
      expect(invoice.balanceDueCents, 0); // K column
    });

    test('tax rounds to the nearest cent', () {
      final invoice = _invoice(amountCents: 10001, taxRatePercent: 8.5);
      expect(invoice.taxCents, 850);
    });
  });

  group('Status logic (column L)', () {
    final now = DateTime(2026, 3, 1);

    test('Paid when balance is zero', () {
      final invoice = _invoice(
        amountPaidCents: 108000,
        dueDate: DateTime(2025, 1, 1),
      );
      expect(invoice.statusAt(now), InvoiceStatus.paid);
    });

    test('Overdue when money owed and past due date', () {
      final invoice = _invoice(dueDate: DateTime(2026, 2, 1));
      expect(invoice.statusAt(now), InvoiceStatus.overdue);
      expect(invoice.statusLabel, 'Overdue');
    });

    test('Partially Paid when some money paid, not overdue', () {
      final invoice = _invoice(
        amountPaidCents: 40000,
        dueDate: DateTime(2026, 4, 1),
      );
      expect(invoice.statusAt(now), InvoiceStatus.partiallyPaid);
    });

    test('Open when nothing paid and not yet due', () {
      final invoice = _invoice(dueDate: DateTime(2026, 4, 1));
      expect(invoice.statusAt(now), InvoiceStatus.open);
      expect(invoice.statusLabel, 'Open');
      expect(invoice.owesMoney, isTrue);
    });
  });

  group('Serialization', () {
    test('toJson / fromJson round-trips', () {
      final invoice = _invoice(
        amountCents: 250000,
        taxRatePercent: 0,
        amountPaidCents: 100000,
        dueDate: DateTime(2026, 2, 15),
      ).copyWith(paymentMethod: 'Bank Transfer', notes: 'Deposit pending');

      final restored = InvoiceEntry.fromJson(invoice.toJson());

      expect(restored.id, invoice.id);
      expect(restored.invoiceNumber, invoice.invoiceNumber);
      expect(restored.client, invoice.client);
      expect(restored.amountCents, invoice.amountCents);
      expect(restored.taxRatePercent, invoice.taxRatePercent);
      expect(restored.amountPaidCents, invoice.amountPaidCents);
      expect(restored.invoiceDate, invoice.invoiceDate);
      expect(restored.dueDate, invoice.dueDate);
      expect(restored.paymentMethod, 'Bank Transfer');
      expect(restored.notes, 'Deposit pending');
    });
  });
}
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../application/invoice_tracker_controller.dart';
import '../domain/invoice_entry.dart';
import 'invoice_form_dialog.dart';

String formatCents(int cents) => NumberFormat('#,##0.00').format(cents / 100);

class InvoiceTrackerScreen extends ConsumerWidget {
  const InvoiceTrackerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoices = ref.watch(invoiceTrackerProvider);

    final now = DateTime.now();
    int totalInvoiced = 0;
    int taxCollected = 0;
    int totalPaid = 0;
    int outstanding = 0;
    int openCount = 0;
    int overdueCount = 0;
    for (final invoice in invoices) {
      totalInvoiced += invoice.totalCents;
      taxCollected += invoice.taxCents;
      totalPaid += invoice.amountPaidCents;
      outstanding += invoice.balanceDueCents;
      if (invoice.owesMoney) openCount++;
      if (invoice.statusAt(now) == InvoiceStatus.overdue) overdueCount++;
    }

    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice Tracker'),
        actions: [
          IconButton(
            tooltip: 'Add invoice',
            icon: const Icon(Icons.add),
            onPressed: () => _openForm(ref),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add_invoice'),
        onPressed: () => _openForm(ref),
        icon: const Icon(Icons.add),
        label: const Text('Add Invoice'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _StatCard(
                  label: 'Total Invoiced',
                  value: formatCents(totalInvoiced),
                  color: scheme.primary,
                ),
                _StatCard(
                  label: 'Tax Collected',
                  value: formatCents(taxCollected),
                  color: scheme.tertiary,
                ),
                _StatCard(
                  label: 'Total Paid',
                  value: formatCents(totalPaid),
                  color: scheme.secondary,
                ),
                _StatCard(
                  label: 'Outstanding',
                  value: formatCents(outstanding),
                  color: scheme.error,
                ),
                _StatCard(
                  label: 'Invoices Logged',
                  value: invoices.length.toString(),
                  color: scheme.onSurfaceVariant,
                ),
                _StatCard(
                  label: 'Unpaid / Open',
                  value: openCount.toString(),
                  color: scheme.error,
                ),
                _StatCard(
                  label: 'Overdue',
                  value: overdueCount.toString(),
                  color: scheme.error,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Oldest unpaid first. Red = money owed / overdue.',
              style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: invoices.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.request_quote_outlined, size: 56, color: scheme.outline),
                        const SizedBox(height: 12),
                        Text('No invoices yet.', style: textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                          'Tap "Add Invoice" to log your first one — just like the Excel file.',
                          style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      dataRowMinHeight: 44,
                      dataRowMaxHeight: 64,
                      sortColumnIndex: 0,
                      columns: const [
                        DataColumn(label: Text('Invoice #')),
                        DataColumn(label: Text('Client')),
                        DataColumn(label: Text('Description')),
                        DataColumn(label: Text('Invoice Date')),
                        DataColumn(label: Text('Due Date')),
                        DataColumn(label: Text('Amount'), numeric: true),
                        DataColumn(label: Text('Tax'), numeric: true),
                        DataColumn(label: Text('Total'), numeric: true),
                        DataColumn(label: Text('Paid'), numeric: true),
                        DataColumn(label: Text('Balance'), numeric: true),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Method')),
                        DataColumn(label: Text('Paid Date')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: [
                        for (final invoice in _sorted(invoices))
                          _invoiceRow(context, ref, invoice),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  List<InvoiceEntry> _sorted(List<InvoiceEntry> invoices) {
    final unpaid = [
      for (final i in invoices)
        if (i.owesMoney) i,
    ]..sort((a, b) {
        final aOverdue = a.status == InvoiceStatus.overdue ? 0 : 1;
        final bOverdue = b.status == InvoiceStatus.overdue ? 0 : 1;
        if (aOverdue != bOverdue) return aOverdue.compareTo(bOverdue);
        return a.dueDate.compareTo(b.dueDate);
      });
    final settled = [
      for (final i in invoices)
        if (!i.owesMoney) i,
    ]..sort((a, b) => a.invoiceDate.compareTo(b.invoiceDate));
    return [...unpaid, ...settled];
  }

  DataRow _invoiceRow(BuildContext context, WidgetRef ref, InvoiceEntry invoice) {
    final scheme = Theme.of(context).colorScheme;
    final statusStyle = invoice.owesMoney
        ? TextStyle(color: scheme.error, fontWeight: FontWeight.w600)
        : TextStyle(color: scheme.primary, fontWeight: FontWeight.w600);

    return DataRow(
      cells: [
        DataCell(Text(invoice.invoiceNumber, style: const TextStyle(fontWeight: FontWeight.w600))),
        DataCell(Text(invoice.client)),
        DataCell(Text(invoice.description)),
        DataCell(Text(DateFormat('dd/MM/yyyy').format(invoice.invoiceDate))),
        DataCell(
          Text(
            DateFormat('dd/MM/yyyy').format(invoice.dueDate),
            style: invoice.status == InvoiceStatus.overdue ? statusStyle : null,
          ),
        ),
        DataCell(Text(formatCents(invoice.amountCents))),
        DataCell(Text(formatCents(invoice.taxCents))),
        DataCell(Text(formatCents(invoice.totalCents))),
        DataCell(Text(formatCents(invoice.amountPaidCents))),
        DataCell(
          Text(
            formatCents(invoice.balanceDueCents),
            style: TextStyle(
              color: invoice.owesMoney ? scheme.error : scheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        DataCell(
          Text(
            invoice.statusLabel,
            style: statusStyle,
          ),
        ),
        DataCell(Text(invoice.paymentMethod.isEmpty ? '—' : invoice.paymentMethod)),
        DataCell(
          Text(
            invoice.paidDate == null ? '—' : DateFormat('dd/MM/yyyy').format(invoice.paidDate!),
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Edit',
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: () => _openForm(ref, initial: invoice),
              ),
              IconButton(
                tooltip: 'Delete',
                icon: Icon(Icons.delete_outline, size: 20, color: scheme.error),
                onPressed: () => _confirmDelete(ref, invoice),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _openForm(WidgetRef ref, {InvoiceEntry? initial}) {
    final result = showDialog<InvoiceEntry>(
      context: ref.context,
      builder: (context) => InvoiceFormDialog(initial: initial),
    );
    result.then((entry) {
      if (entry == null) return;
      final controller = ref.read(invoiceTrackerProvider.notifier);
      if (initial == null) {
        controller.add(entry);
      } else {
        controller.update(entry);
      }
    });
  }

  void _confirmDelete(WidgetRef ref, InvoiceEntry invoice) {
    showDialog<void>(
      context: ref.context,
      builder: (context) => AlertDialog(
        title: const Text('Delete invoice?'),
        content: Text('${invoice.invoiceNumber} — ${invoice.client} will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(invoiceTrackerProvider.notifier).remove(invoice.id);
              Navigator.of(context).pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Container(
        width: 148,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(color: color, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
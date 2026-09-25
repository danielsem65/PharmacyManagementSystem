import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/invoice_entry.dart';

const List<String> kPaymentMethods = ['Cash', 'Bank Transfer', 'GCash', 'Card'];

class InvoiceFormDialog extends StatefulWidget {
  const InvoiceFormDialog({super.key, this.initial});

  final InvoiceEntry? initial;

  @override
  State<InvoiceFormDialog> createState() => _InvoiceFormDialogState();
}

class _InvoiceFormDialogState extends State<InvoiceFormDialog> {
  late final TextEditingController _number;
  late final TextEditingController _client;
  late final TextEditingController _description;
  late final TextEditingController _amount;
  late final TextEditingController _taxRate;
  late final TextEditingController _amountPaid;
  late final TextEditingController _notes;
  late final String _paymentMethod;
  DateTime? _invoiceDate;
  DateTime? _dueDate;
  DateTime? _paidDate;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _number = TextEditingController(text: initial?.invoiceNumber ?? '');
    _client = TextEditingController(text: initial?.client ?? '');
    _description = TextEditingController(text: initial?.description ?? '');
    _amount = TextEditingController(
      text: initial == null ? '' : _formatMoney(initial.amountCents),
    );
    _taxRate = TextEditingController(
      text: initial == null ? '' : _formatRate(initial.taxRatePercent),
    );
    _amountPaid = TextEditingController(
      text: initial == null ? '' : _formatMoney(initial.amountPaidCents),
    );
    _notes = TextEditingController(text: initial?.notes ?? '');
    _paymentMethod = initial?.paymentMethod ?? kPaymentMethods.first;
    _invoiceDate = initial?.invoiceDate;
    _dueDate = initial?.dueDate;
    _paidDate = initial?.paidDate;
  }

  @override
  void dispose() {
    _number.dispose();
    _client.dispose();
    _description.dispose();
    _amount.dispose();
    _taxRate.dispose();
    _amountPaid.dispose();
    _notes.dispose();
    super.dispose();
  }

  static String _formatMoney(int cents) => (cents / 100).toStringAsFixed(2);
  static String _formatRate(double rate) =>
      rate == rate.roundToDouble() ? rate.toStringAsFixed(0) : rate.toString();

  int? _parseMoney(String raw) {
    final cleaned = raw.replaceAll(',', '').trim();
    final value = double.tryParse(cleaned);
    if (value == null || value < 0) return null;
    return (value * 100).round();
  }

  double? _parseRate(String raw) {
    final cleaned = raw.replaceAll(',', '').trim();
    final value = double.tryParse(cleaned);
    if (value == null || value < 0) return null;
    return value;
  }

  Future<void> _pickDate(bool isDue) async {
    final now = DateTime.now();
    final firstDate = isDue ? (DateTime(now.year - 5)) : DateTime(now.year - 10);
    final lastDate = DateTime(now.year + 20);
    final picked = await showDatePicker(
      context: context,
      initialDate: (_invoiceDate ?? now).isBefore(firstDate) ? firstDate : (_invoiceDate ?? now),
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked == null) return;
    final day = _dateOnly(picked);
    if (isDue) {
      setState(() => _dueDate = day);
    } else {
      setState(() => _invoiceDate = day);
    }
  }

  Future<void> _pickPaidDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _paidDate ?? now,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 20),
    );
    if (picked == null) return;
    setState(() => _paidDate = _dateOnly(picked));
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  String? _validateRequired(String? value) =>
      (value == null || value.trim().isEmpty) ? 'Required' : null;

  String? _validateMoney(String? value) =>
      _parseMoney(value ?? '') == null ? 'Enter a valid amount (0 or more)' : null;

  String? _validateRate(String? value) =>
      _parseRate(value ?? '') == null ? 'Enter a valid %' : null;

  void _submit() {
    final form = Form.of(context);
    if (!(form.validate())) return;
    final amount = _parseMoney(_amount.text)!;
    final taxRate = _parseRate(_taxRate.text)!;
    final amountPaid = _parseMoney(_amountPaid.text)!;
    final base = widget.initial ?? InvoiceEntry.create(
          invoiceNumber: '',
          client: '',
          description: '',
          invoiceDate: DateTime.now(),
          dueDate: DateTime.now(),
          amountCents: 0,
          taxRatePercent: 0,
          amountPaidCents: 0,
        );
    final entry = base.copyWith(
      invoiceNumber: _number.text.trim(),
      client: _client.text.trim(),
      description: _description.text.trim(),
      invoiceDate: _invoiceDate ?? DateTime.now(),
      dueDate: _dueDate ?? DateTime.now(),
      amountCents: amount,
      taxRatePercent: taxRate,
      amountPaidCents: amountPaid,
      paidDate: _paidDate,
      clearPaidDate: _paidDate == null,
      paymentMethod: _paymentMethod,
      notes: _notes.text.trim(),
    );
    Navigator.of(context).pop(entry);
  }

  Widget _dateField({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
    VoidCallback? onClear,
    required IconData icon,
  }) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: onClear == null
              ? null
              : IconButton(
                  tooltip: 'Clear $label',
                  icon: const Icon(Icons.close),
                  onPressed: onClear,
                ),
        ),
        child: Text(value == null ? 'Not set' : '${_dateOnly(value).day}/${_dateOnly(value).month}/${_dateOnly(value).year}'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Add Invoice' : 'Edit Invoice'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Form(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  key: const Key('invoice_number'),
                  controller: _number,
                  decoration: const InputDecoration(labelText: 'Invoice #', hintText: 'INV-001'),
                  validator: _validateRequired,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('invoice_client'),
                  controller: _client,
                  decoration: const InputDecoration(labelText: 'Client', hintText: 'Client / customer name'),
                  validator: _validateRequired,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('invoice_description'),
                  controller: _description,
                  decoration: const InputDecoration(labelText: 'Description', hintText: 'What the invoice is for'),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _dateField(
                        label: 'Invoice Date',
                        value: _invoiceDate,
                        onTap: () => _pickDate(false),
                        icon: Icons.event_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _dateField(
                        label: 'Due Date',
                        value: _dueDate,
                        onTap: () => _pickDate(true),
                        icon: Icons.event_available_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: const Key('invoice_amount'),
                        controller: _amount,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                        decoration: const InputDecoration(labelText: 'Amount', hintText: 'e.g. 1000'),
                        validator: _validateMoney,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        key: const Key('invoice_tax_rate'),
                        controller: _taxRate,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                        decoration: const InputDecoration(labelText: 'Tax Rate (%)', hintText: 'e.g. 8'),
                        validator: _validateRate,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _amountPaid,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                        decoration: const InputDecoration(labelText: 'Amount Paid', hintText: '0'),
                        validator: _validateMoney,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _paymentMethod,
                        decoration: const InputDecoration(labelText: 'Payment Method'),
                        items: [
                          for (final method in kPaymentMethods)
                            DropdownMenuItem(value: method, child: Text(method)),
                        ],
                        onChanged: (value) {
                          if (value != null) setState(() => _paymentMethod = value);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _dateField(
                  label: 'Paid Date',
                  value: _paidDate,
                  onTap: _pickPaidDate,
                  onClear: _paidDate == null ? null : () => setState(() => _paidDate = null),
                  icon: Icons.verified_outlined,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notes,
                  decoration: const InputDecoration(labelText: 'Notes', hintText: 'Anything extra to remember'),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('invoice_save'),
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
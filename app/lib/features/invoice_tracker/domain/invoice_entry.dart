/// Mirrors the Invoice_Tracker.xlsx columns A-O and its live formulas.
enum InvoiceStatus { open, partiallyPaid, overdue, paid }

class InvoiceEntry {
  const InvoiceEntry({
    required this.id,
    required this.invoiceNumber,
    required this.client,
    required this.description,
    required this.invoiceDate,
    required this.dueDate,
    required this.amountCents,
    required this.taxRatePercent,
    required this.amountPaidCents,
    this.paidDate,
    this.paymentMethod = '',
    this.notes = '',
  });

  InvoiceEntry.create({
    required this.invoiceNumber,
    required this.client,
    required this.description,
    required this.invoiceDate,
    required this.dueDate,
    required this.amountCents,
    required this.taxRatePercent,
    required this.amountPaidCents,
    this.paidDate,
    this.paymentMethod = '',
    this.notes = '',
  }) : id = DateTime.now().microsecondsSinceEpoch.toString();

  final String id;

  // Column A
  final String invoiceNumber;
  // Column B
  final String client;
  // Column C
  final String description;
  // Column D
  final DateTime invoiceDate;
  // Column E
  final DateTime dueDate;
  // Column F — stored in minor units (cents) per repo money convention
  final int amountCents;
  // Column G
  final double taxRatePercent;
  // Column J
  final int amountPaidCents;
  // Column M
  final DateTime? paidDate;
  // Column N
  final String paymentMethod;
  // Column O
  final String notes;

  // Column H (auto)
  int get taxCents => (amountCents * taxRatePercent / 100).round();

  // Column I (auto)
  int get totalCents => amountCents + taxCents;

  // Column K (auto)
  int get balanceDueCents => totalCents - amountPaidCents;

  bool get owesMoney => balanceDueCents > 0;

  InvoiceStatus statusAt(DateTime now) {
    if (balanceDueCents <= 0) return InvoiceStatus.paid;
    if (now.isAfter(dueDate)) return InvoiceStatus.overdue;
    if (amountPaidCents > 0) return InvoiceStatus.partiallyPaid;
    return InvoiceStatus.open;
  }

  InvoiceStatus get status => statusAt(DateTime.now());

  String get statusLabel => switch (status) {
        InvoiceStatus.paid => 'Paid',
        InvoiceStatus.overdue => 'Overdue',
        InvoiceStatus.partiallyPaid => 'Partially Paid',
        InvoiceStatus.open => 'Open',
      };

  InvoiceEntry copyWith({
    String? invoiceNumber,
    String? client,
    String? description,
    DateTime? invoiceDate,
    DateTime? dueDate,
    int? amountCents,
    double? taxRatePercent,
    int? amountPaidCents,
    DateTime? paidDate,
    bool clearPaidDate = false,
    String? paymentMethod,
    String? notes,
  }) {
    return InvoiceEntry(
      id: id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      client: client ?? this.client,
      description: description ?? this.description,
      invoiceDate: invoiceDate ?? this.invoiceDate,
      dueDate: dueDate ?? this.dueDate,
      amountCents: amountCents ?? this.amountCents,
      taxRatePercent: taxRatePercent ?? this.taxRatePercent,
      amountPaidCents: amountPaidCents ?? this.amountPaidCents,
      paidDate: clearPaidDate ? null : (paidDate ?? this.paidDate),
      paymentMethod: paymentMethod ?? this.paymentMethod,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'invoiceNumber': invoiceNumber,
        'client': client,
        'description': description,
        'invoiceDate': invoiceDate.toIso8601String(),
        'dueDate': dueDate.toIso8601String(),
        'amountCents': amountCents,
        'taxRatePercent': taxRatePercent,
        'amountPaidCents': amountPaidCents,
        'paidDate': paidDate?.toIso8601String(),
        'paymentMethod': paymentMethod,
        'notes': notes,
      };

  factory InvoiceEntry.fromJson(Map<String, dynamic> json) {
    final paidDateRaw = json['paidDate'] as String?;
    return InvoiceEntry(
      id: json['id'] as String,
      invoiceNumber: json['invoiceNumber'] as String,
      client: json['client'] as String,
      description: json['description'] as String? ?? '',
      invoiceDate: DateTime.parse(json['invoiceDate'] as String),
      dueDate: DateTime.parse(json['dueDate'] as String),
      amountCents: json['amountCents'] as int,
      taxRatePercent: (json['taxRatePercent'] as num).toDouble(),
      amountPaidCents: json['amountPaidCents'] as int? ?? 0,
      paidDate: paidDateRaw == null ? null : DateTime.parse(paidDateRaw),
      paymentMethod: json['paymentMethod'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
    );
  }
}
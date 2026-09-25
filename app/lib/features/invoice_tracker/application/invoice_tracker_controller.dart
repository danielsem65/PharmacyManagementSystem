import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/invoice_entry.dart';

/// Stores invoices on-device (Windows/Android/web) so the tracker works
/// offline like the original Excel file — no account required.
abstract interface class InvoicePersistence {
  Future<List<InvoiceEntry>?> load();
  Future<void> save(List<InvoiceEntry> invoices);
}

class SharedPrefsInvoicePersistence implements InvoicePersistence {
  static const String _key = 'invoice_tracker.v1';

  @override
  Future<List<InvoiceEntry>?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    final list = jsonDecode(raw) as List<dynamic>;
    return [
      for (final item in list) InvoiceEntry.fromJson((item as Map).cast<String, dynamic>()),
    ];
  }

  @override
  Future<void> save(List<InvoiceEntry> invoices) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode([for (final i in invoices) i.toJson()]);
    await prefs.setString(_key, json);
  }
}

final invoicePersistenceProvider = Provider<InvoicePersistence>((ref) {
  return SharedPrefsInvoicePersistence();
});

final invoiceTrackerProvider =
    StateNotifierProvider<InvoiceTrackerController, List<InvoiceEntry>>((ref) {
  final controller = InvoiceTrackerController(ref.watch(invoicePersistenceProvider));
  controller.init();
  return controller;
});

class InvoiceTrackerController extends StateNotifier<List<InvoiceEntry>> {
  InvoiceTrackerController(this._persistence) : super(const []);

  final InvoicePersistence _persistence;

  Future<void> init() async {
    final loaded = await _persistence.load();
    if (loaded != null) {
      state = List<InvoiceEntry>.unmodifiable(loaded);
    }
  }

  void add(InvoiceEntry entry) {
    state = List<InvoiceEntry>.unmodifiable([...state, entry]);
    _persistence.save(state);
  }

  void update(InvoiceEntry entry) {
    state = List<InvoiceEntry>.unmodifiable([
      for (final existing in state)
        if (existing.id == entry.id) entry else existing,
    ]);
    _persistence.save(state);
  }

  void remove(String id) {
    state = List<InvoiceEntry>.unmodifiable(
      state.where((entry) => entry.id != id).toList(),
    );
    _persistence.save(state);
  }
}
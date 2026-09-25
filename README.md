# Pharmacy Management System

A production-grade pharmacy ERP/POS platform: Point of Sale, sales, invoices,
receipts, customers, medicines, inventory, batch & expiry tracking (FEFO),
suppliers, purchases, employees, attendance, expenses, payments, reports,
profit tracking, audit logs, role-based permissions, dashboard, notifications
and settings — multi-branch ready.

## Stack

- **Client:** Flutter (Windows desktop POS + Android/iOS mobile) — in `app/`
- **Backend:** Supabase (PostgreSQL 15+, Auth, RLS security)
- **Money:** `numeric(14,2)` in Postgres, integer minor units in Dart — never floats
- **CI:** GitHub Actions — validates the DB schema, runs Flutter analyze/test,
  and builds Windows desktop (PC), Android APK, and web

## Repository layout

```
docs/                 architecture, database schema, phase plan
supabase/
  migrations/         versioned SQL migrations (apply in order)
  seed.sql            development/demo seed data (never in prod)
app/                  Flutter application
  lib/                feature-first clean architecture
  test/               unit + widget tests
.github/workflows/    CI pipeline
```

## Phases

See `docs/PHASES.md`. Progress is tracked against the master prompt's
14 phases and final acceptance checklist.

## Local development

You do **not** need Flutter installed locally — CI runs the full toolchain.
To work locally:

```bash
cd app
flutter pub get
flutter run -d windows    # or -d chrome / an Android device
```

Run with real Supabase credentials:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

Without `--dart-define`, the app uses placeholder credentials and login will
fail — expected until a project is linked.

## Offline Invoice Tracker (works without an account)

An Excel-style invoice tracker is built into the app and needs **no login or
Supabase**: it mirrors `Invoice_Tracker.xlsx` (auto tax, total, balance and
status; paid / overdue / part-paid / open highlighting; summary block).

- Open it from the login screen via **"Open Invoice Tracker (Excel)"**, or run
  `flutter run -d windows` and browse to `/tracker`.
- Data is saved locally on-device (Windows, Android, web) as JSON, so it is
  fully offline — just like the spreadsheet.
- Model/tests live in `app/lib/features/invoice_tracker/`.

## Database

Migrations live in `supabase/migrations/`. Apply in order against a Supabase
Postgres instance (or via the Supabase CLI). CI validates the full schema +
seed against a real Postgres 15 container on every push, so the schema is
always verified.

The first user to sign up is created as `staff` by default; promote a test
user to `owner` (or run the seed) to activate the full UI.

## How the app stays secure

- Client never computes authoritative money/inventory: sales, purchases,
  returns and adjustments run as atomic Postgres functions.
- Row Level Security gates every table; role permissions mirror both server
  policies and the Flutter UI.
- Completed invoices are voided, never deleted. Every stock change writes an
  audit-able `stock_movements` row and an `audit_logs` entry.

See `docs/ARCHITECTURE.md` and `docs/DATABASE.md` for details.
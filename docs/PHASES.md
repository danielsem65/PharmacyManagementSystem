# Pharmacy Management System — Implementation Phases

Every phase lands as a commit + passing GitHub Actions CI before the next
phase starts. Flutter is **not** installed locally; CI installs it and runs
`flutter analyze`, `flutter test`, `dart format`, and builds
(web / APK / Windows).

## PHASE 0 — Foundation (current)
- [x] Inspect project.
- [ ] Docs: architecture, database, phases (this file).
- [ ] GitHub repo + Actions CI pipeline.
- [ ] Supabase schema + RLS + seed migration.

## PHASE 1 — Architecture + database  ✅ DOING NOW
- Supabase project (create at console / via CLI in CI).
- `supabase/migrations/0001_init.sql`: full schema (DATABASE.md), indexes,
  triggers, RLS policies, `SECURITY DEFINER` helpers.
- `supabase/seed.sql` dev data: categories, products w/ batches, customers,
  suppliers, employees, expenses, sample sales/purchases.
- CI job applies migrations (via supabase CLI) and reports schema errors.

## PHASE 2 — Authentication + roles
- Flutter app scaffold (clean architecture, Riverpod, GoRouter).
- Login screen (email/password), onboarding.
- `rpc.login_context` → role + permission catalog into app state.
- GoRouter guardian: unauthenticated → login; role-gated routes.
- Permissions catalog repo; profile screen; change password.
- Tests: auth reducer, permission checks.

## PHASE 3 — Products + inventory
- Products CRUD (owner/manager/inventory_manager), categories, suppliers.
- Batches, expiry tracking, low-stock/reorder calc.
- Stock list with filters (expired, expiring, low), stock value.
- Stock adjustment flow (reason + audit) via `rpc.adjust_stock`.
- Tests: product validation, batch/expiry math, low-stock rules.

## PHASE 4 — POS + sales
- Fast POS: search, barcode input, category suggestions, cart, quantities,
  discounts, customer select/walk-in, payment methods, change calc.
- `rpc.complete_sale` (FEFO, atomic, produces invoice + movements + payments).
- Hold/resume sale; void sale (permission + audit).
- Tests: FEFO selection, insufficient-stock rejection, discount math,
  payment/change logic, atomicity (rollback on failure).

## PHASE 5 — Invoices + receipts + printing
- Invoice list/search/filter; detail; print; PDF; reprint; void.
- Thermal-receipt layout, configurable size; logo/address from settings.
- Tests: invoice numbering, totals, balance calculation.

## PHASE 6 — Customers + suppliers
- Customer CRUD + walk-in support; purchase history, credit.
- Supplier CRUD, purchase history, outstanding balances/payments.
- Tests: credit cap, outstanding balance math.

## PHASE 7 — Purchases + stock receiving
- PO workflow (draft/ordered/partial/received/cancelled).
- Receiving captures batch number, expiry, qty, cost → atomic stock update.
- Tests: receiving reduces PO items, creates batches, updates inventory.

## PHASE 8 — Employees + attendance
- Employee CRUD, roles assignment.
- Check-in/check-out (no duplicate open check-ins), attendance dashboard.
- Tests: duplicate check-in prevention, duration calc.

## PHASE 9 — Expenses
- Expense CRUD + categories + attachments + filters.
- Tests: validation, categorization.

## PHASE 10 — Dashboard + reports
- Dashboard KPIs + charts (period filter), revenue vs expenses, top products.
- Reports: sales, product sales, profit (Revenue − COGS = Gross; −Expenses =
  Net, methodology shown in UI), inventory value, expiry, staff, expenses.
- Export CSV / PDF / print.
- Tests: profit-chain math, report aggregation.

## PHASE 11 — Notifications + audit logs
- Notification centre (low stock / expiring / expired / purchases / balances).
- Configurable thresholds; audit log viewer (owner/manager).
- Tests: threshold triggers, audit entries on key actions.

## PHASE 12 — Security hardening
- RLS policy review; function permission checks; rate limiting on auth.
- Input validation audit; XSS-safe rendering; key rotation docs.
- DB backups enabled (Supabase PITR + scheduled export) + restore docs.

## PHASE 13 — Testing (full sweep)
- Business-logic test coverage for all critical flows + edge cases
  (e.g. 2 units left, sell 3 → rejected).
- Full `flutter analyze` + `flutter test` green on CI.

## PHASE 14 — Production preparation
- `.env`/`--dart-define` configuration, build signing, release builds
  (APK, Windows installer), deployment docs, printer + barcode scanner setup
  docs, user training guide.

---

## Acceptance checklist (from master prompt)
Auth, roles/permissions, products, inventory, batch, expiries, FEFO, POS,
sales, payments, invoices, receipts, customers, suppliers, purchases, returns,
expenses, employees, attendance, reports, dashboard, notifications, audit,
search, DB constraints, security, error handling, tests, prod build, no
console errors — all verified by CI before this project is declared done.
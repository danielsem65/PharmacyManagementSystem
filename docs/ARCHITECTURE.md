# Pharmacy Management System — Architecture

## Overview

A production-grade pharmacy management platform (ERP/POS) for a real pharmacy,
built to scale to multiple branches. The system covers Point of Sale, sales,
invoices, receipts, customers, products/medicines, batch & expiry tracking,
FEFO (First Expiry, First Out), suppliers, purchases, employees, attendance,
expenses, payments, reports, profit tracking, audit logs, role-based access,
dashboard, notifications, and settings.

This document is the source of truth for the technical design.

## Stack

| Layer        | Technology                                                   |
| ------------ | ------------------------------------------------------------ |
| Client       | Flutter (Windows desktop for POS, Android/iOS for mobile)    |
| State        | Riverpod (compile-safe providers, no codegen)                |
| Routing      | GoRouter with role-aware redirects                           |
| Backend      | Supabase (PostgreSQL 15+, Auth, Realtime)                    |
| Database     | PostgreSQL with decimal money, FKs, indexes, RLS security    |
| Auth         | Supabase Auth (email/password) + custom App Roles via JWT    |
| Printing     | thermally optimised receipt layout; PDF generation reusable  |
| CI/CD        | GitHub Actions (analyze, test, build apk/web/windows)        |
| Testing      | `flutter test` — pure Dart unit tests for business logic + widget tests |

## Architecture Principles

1. **Client must never be trusted** for money/inventory calculations.
   Every sale, return, purchase, and adjustment is a single atomic database
   transaction; totals are recomputed server-side from line items.
2. **Money is decimal, never float.** All monetary columns are `NUMERIC`
   (`decimal`) and all Dart money logic uses integer minor units.
3. **Inventory is always consistent.** No quantity can go negative, expired
   batches cannot be sold, and there is no anonymous "total stock" when
   batch tracking is enabled.
4. **Everything is auditable.** Every stock movement and every sensitive
   action writes an audit + stock movement record that users cannot edit.
5. **FEFO by default.** Sales deduct from the batch with the earliest expiry.
6. **Invoices are immutable.** Completed invoices are never deleted; any
   rejection is a void/cancel with an audit record.

## High-Level Flow

```
Flutter app ── Supabase Client (anon key, RLS enforced) ──> PostgreSQL
   │                                                          │
   ├─ Auth: email/password ───────────────────────────────►  auth.users
   │                                                          │
   └─ Business operations ─ (Postgres RPC functions) ───────►  atomic RPCs
```

Security-critical operations (complete_sale, receive_purchase, process_return,
adjust_stock) are implemented as **Postgres functions** (`SECURITY DEFINER`,
permission-checked) that run the full transaction server-side. RLS provides
row-level gating for every table.

## Auth & Roles

- Supabase Auth manages identity; a `public.profiles` table stores role +
  employee link.
- Roles: `owner`, `manager`, `pharmacist`, `cashier`, `inventory_manager`,
  `staff`.
- Permissions are stored as `permission` + `role_permission` rows; every
  Postgres function and every client route checks them.
- The JWT carries `app_role`; RLS policies and RPCs cross-check it.
- Client routes and sidebar items are gated by the same permission catalog so
  the UI and the backend policy stay aligned.

## Monorepo Layout

```
.
├─ docs/                 # architecture, database, phases, ops docs
├─ supabase/
│  ├─ migrations/        # versioned SQL migrations (Phase 1)
│  ├─ seed.sql           # development/demo seed data
│  └─ config.toml        # local supabase config (if used)
└─ app/                  # Flutter application
   ├─ lib/
   │  ├─ main.dart
   │  ├─ core/           # theme, router, permissions, assets, utils
   │  ├─ data/           # supabase client, repositories, DTOs
   │  ├─ models/         # domain entities
   │  ├─ features/       # one folder per feature (auth, pos, products, …)
   │  │  ├─ <feature>/
   │  │  │  ├─ application/  # providers + pure logic
   │  │  │  ├─ data/         # feature repositories
   │  │  │  └─ presentation/ # screens + widgets
   │  ├─ shared/         # reusable widgets (tables, forms, alerts)
   │  └─ theme/          # design system
   └─ test/
```

## Data Integrity (Core Rules)

- Negative inventory is impossible (DB check + RPC guard).
- Expired products are not sellable (sale RPC rejects).
- A completed invoice cannot be deleted (no DELETE path; void instead).
- All stock adjustments require a `reason`.
- Refunds/returns reference an original sale.
- A purchase receipt atomically increases stock and creates batches.
- A worker cannot have two open check-ins (partial unique index).
- Restricted financial reports are protected by permission checks server-side.

## Multi-Branch Readiness

The schema is branch-aware from day one at zero cost:

- `branches` table with a default "Main branch".
- `org_id`/`branch_id` columns on all operational tables.
- RLS policies scope by branch; multi-branch is a future config + new policy
  release, not a schema rewrite.

## Offline-First / Future-Ready

V1 is online-first. The architecture deliberately separates **pure business
logic** (models, money, FEFO, receipt layout) from **data access** so an
offline queue + local cache (e.g. SQLite mirror + pending-sales queue syncing
through the same RPCs) can be added without changing business code.

## Communication & Validation Strategy

| Layer              | Validation                                                        |
| ------------------ | ----------------------------------------------------------------- |
| Flutter forms      | client-side UX validation only                                    |
| Supabase RLS       | row-level authorization                                           |
| Postgres functions | all authoritative money/inventory rules, atomic transactions      |
| DB constraints     | NOT NULL, CHECK (qty >= 0, money decimal), UNIQUE, FK             |

Never bypass the DB layer with client-side trust.
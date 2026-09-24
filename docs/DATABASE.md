# Pharmacy Management System — Database Schema

Database: **PostgreSQL 15+** hosted on Supabase.

Conventions:

- All tables are in the `public` schema unless noted.
- IDs are `uuid` with `gen_random_uuid()` default.
- Money is `numeric(14,2)`. **Never use floating point for money.**
- Quantity columns are `numeric(14,2)` (fractions allowed for liquids) — never negative.
- Every operational table has `created_at timestamptz default now()` and
  `updated_at timestamptz default now()`, maintained by a trigger.
- Soft deletion: `deleted_at timestamptz null`.
- Every row is scoped by `branch_id` (multi-branch ready). `org_id` exists at
  the top of `branches`.

## Enum-like helpers

| Type        | Values                                                                                       |
| ----------- | -------------------------------------------------------------------------------------------- |
| payment_method | cash, mobile_money, card, bank, credit, other                                            |
| sale_status | active, voided                                                                               |
| purchase_status | draft, ordered, partially_received, received, cancelled                                  |
| movement_type | purchase, sale, return, adjustment, damage, expired, disposal, transfer, correction     |
| expense type  | via `expense_categories` table (seed: Rent, Electricity, Water, Internet, Salaries, Transport, Maintenance, Supplies, Marketing, Other) |

## Tables

### auth / identity (Supabase managed)
`auth.users` — identity only. Public profile:

**profiles**
| column | type | notes |
| ------ | ---- | ----- |
| id | uuid PK | = auth.users.id |
| branch_id | uuid FK -> branches | |
| employee_id | uuid FK -> employees | nullable |
| full_name | text | |
| role | text | owner, manager, pharmacist, cashier, inventory_manager, staff |
| phone, email, avatar_url | text | |
| is_active | bool default true | |
| last_login_at | timestamptz | |
| created_at, updated_at | | |

### organization
**organizations**
| column | type | notes |
| ------ | ---- | ----- |
| id | uuid PK | |
| name | text | |
| branch_count | int | |
| created_at, updated_at | | |

**branches**
| column | type | notes |
| ------ | ---- | ----- |
| id | uuid PK | |
| org_id | uuid FK -> organizations | |
| name | text | e.g. "Main Branch" |
| address, phone, email | text | |
| is_active | bool | |
| created_at, updated_at | | |

### access control
**roles** — id, name (unique), description.
**permissions** — id, code (unique: e.g. `sales.create`, `inventory.adjust`),
category, description.
**role_permissions** — role_id FK, permission_id FK, PK(role_id, permission_id).

### employees
| column | type | notes |
| ------ | ---- | ----- |
| id | uuid PK | |
| branch_id | uuid FK | |
| employee_code | text unique | e.g. EMP-001 |
| full_name, phone, email | text | |
| position, role | text | |
| status | text (active, inactive, terminated) | |
| date_joined | date | |
| created_at, updated_at | | |

**attendance**
| column | type | notes |
| ------ | ---- | ----- |
| id | uuid PK | |
| employee_id FK, branch_id FK | | |
| date | date | |
| check_in, check_out | timestamptz | |
| duration_minutes | int | |
| status | text (present, late, absent, on_leave) | |
| notes | text | |
| UNIQUE partial: one open check-in per employee | | |

### catalog
**categories** — id, name unique, description, parent_id nullable, is_active.

**products**
| column | type | notes |
| ------ | ---- | ----- |
| id | uuid PK | |
| branch_id FK | | |
| sku | text unique | |
| barcode | text unique (nullable per branch) | |
| name | text | |
| generic_name | text | |
| brand | text | |
| category_id FK | | |
| description, dosage_form, strength, unit, pack_size | text | |
| purchase_price numeric(14,2), selling_price numeric(14,2), wholesale_price numeric(14,2) | | |
| min_stock_level numeric, reorder_level numeric | | |
| uses_batches bool default true | | |
| is_active bool | | |
| is_rx bool (prescription required) | | |
| CHECK(selling_price >= 0, purchase_price >= 0) | | |

### batch & inventory
**product_batches**
| column | type | notes |
| ------ | ---- | ----- |
| id | uuid PK | |
| product_id FK, branch_id FK | | |
| batch_number text | | |
| purchase_date, manufactured_date, expiry_date | date | |
| qty_received numeric, qty_remaining numeric | | |
| purchase_price numeric(14,2) | unit cost at receipt | |
| supplier_id FK | | |
| CHECK(qty_remaining >= 0) | | |

**inventory** — one row per product per branch (aggregate snapshot):
id, product_id FK, branch_id FK, quantity numeric, reserved numeric,
available numeric (generated: quantity - reserved),
stock_value numeric(14,2) (from batches, FEFO valuation),
UNIQUE(product_id, branch_id), CHECK(quantity >= 0).

**stock_movements** — append-only:
id, product_id FK, batch_id FK nullable, branch_id FK, quantity numeric
(+in, -out), previous_qty, new_qty, movement_type, user_id FK, reason text,
reference_type, reference_id (e.g. sale id / purchase id), created_at.
Indexes on (product_id, created_at), (movement_type), (reference_id).

### purchasing
**suppliers** — id, branch_id FK, name, company, phone, email, address,
contact_person, tax_id, notes, is_active, timestamps.

**purchases** — id, branch_id FK, supplier_id FK, purchase_number unique,
date, subtotal, discount, tax, total (all numeric(14,2)), status, notes,
created_by FK, received_at, timestamps. CHECK(total >= 0).

**purchase_items** — id, purchase_id FK, product_id FK, quantity,
unit_cost numeric(14,2), discount, tax, line_total numeric(14,2),
qty_received numeric. PK + indexes. CHECK(quantity >= 0).

### sales
**sales** — id, branch_id FK, sale_number unique (INV-yyyy-NNNNNN), pos_cashier FK,
customer_id FK nullable, total numeric(14,2), discount numeric(14,2), tax,
payment_method, amount_paid, change, status (active/voided), void_reason,
created_at. CHECK(total >= 0).

**sale_items** — id, sale_id FK, product_id FK, batch_id FK,
quantity numeric(14,2), unit_price numeric(14,2), discount numeric(14,2),
cost numeric(14,2) (locked at sale for profit), line_total numeric(14,2).
CHECK(quantity > 0).

**payments** — id, sale_id FK, customer_id FK nullable, branch_id FK,
amount numeric(14,2), method, reference, received_by FK, created_at.
CHECK(amount >= 0).

**customer_balances** — id, customer_id FK unique, outstanding numeric(14,2),
CHECK(outstanding >= 0).

### returns / refunds
**returns** — id, branch_id FK, sale_id FK (NOT NULL — must reference a sale),
return_number unique, customer_id FK, total_refund numeric(14,2), reason,
status, processed_by FK, created_at.

**return_items** — id, return_id FK, product_id FK, batch_id FK, quantity,
unit_refund numeric(14,2), line_refund numeric(14,2). CHECK(quantity > 0).

### invoicing
**invoices** — id, sale_id FK, branch_id FK, invoice_number unique,
customer_id FK, issue_date, due_date, subtotal, discount, tax, total,
amount_paid, balance, status (paid, partial, open, voided), printed_count,
created_at. CHECK(total >= 0, balance >= 0).

**invoice_items** — id, invoice_id FK, product_id FK, quantity, unit_price,
discount, line_total.
**invoice_payments** — id, invoice_id FK, amount, method, received_by, created_at.

### expenses
**expense_categories** — id, name unique, description, is_active.
**expenses** — id, branch_id FK, category_id FK, description, amount numeric(14,2),
payment_method, expense_date, recorded_by FK, attachment_url, notes.
CHECK(amount >= 0).

### notifications
**notifications** — id, branch_id FK, recipient_id FK nullable (null = all),
type (low_stock, expiring, expired, purchase_pending, customer_balance,
system), title, body, severity, is_read, created_at.

### audit
**audit_logs** — id, user_id FK, branch_id FK, action, entity, entity_id,
before jsonb, after jsonb, ip, user_agent, metadata jsonb, created_at.
Indexes on (entity, entity_id) and (created_at).

### settings
**pharmacy_settings** — id, branch_id FK unique, pharmacy_name, logo_url,
address, phone, email, business_id, currency, timezone, date_format,
invoice_prefix, invoice_next_number, receipt_width_mm, low_stock_threshold,
expiry_warning_days, fefo_enabled bool, prevent_negative_stock bool,
payment_methods jsonb, tax_rate numeric(14,2). updated_by FK.

### users-permission helpers
**user_sessions** (login history) — id, user_id FK, branch_id FK, logged_in_at,
logged_out_at, ip, user_agent.

## Indexes (high traffic)
- products: (branch_id), barcode unique index, sku unique index, name trigram/GIN for search, category_id.
- sale_items: (sale_id), (product_id), (batch_id).
- stock_movements: (product_id), (batch_id), (reference_id), (created_at desc).
- product_batches: (product_id, expiry_date), (status), (qty_remaining > 0).
- invoice: invoice_number unique, (branch_id, issue_date).
- attendance: (employee_id, date).
- customer search: name/phone indexes.

## Trigger
`set_updated_at()` — sets `updated_at = now()` on UPDATE for all tables that have it.

## Security (RLS summary)
- `profiles`: user reads own row; owner/manager read branch rows.
- Operations tables: RLS `SELECT` for branch staff by role; INSERT/UPDATE/DELETE
  restricted to owner/inventory roles or enforced exclusively via
  `SECURITY DEFINER` RPCs (sales, purchases, returns, adjustments, receipt).
- `audit_logs`: insert-only postgres; SELECT restricted to owner/manager.
- `pharmacy_settings`: UPDATE owner only.

## Authoritative RPC functions (Phase-by-phase, all atomic)
- `rpc.login_context` — returns role/permissions/settings for the app.
- `rpc.complete_sale(payload jsonb)` — validates, FEFO-deducts, creates sale,
  items, payments, invoice, movements: **single transaction**.
- `rpc.hold_sale(id)` / `rpc.resume_sale(id)` / `rpc.void_sale(id, reason)`.
- `rpc.receive_purchase(id)` — atomically creates batches + movements.
- `rpc.process_return(id, items[])` — returns stock to batches, refunds.
- `rpc.adjust_stock(product, batch, qty, reason, type)`.
- `rpc.check_in` / `rpc.check_out`.
- `rpc.next_invoice_number()`.
- `rpc.notifications_for(role)`.

See `docs/PHASES.md` for implementation order.
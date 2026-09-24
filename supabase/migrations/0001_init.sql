-- ============================================================
-- PHARMACY MANAGEMENT SYSTEM — Schema (Phase 1)
-- PostgreSQL 15+ (Supabase)
-- Conventions: UUID PKs, NUMERIC money, no floats, RLS enabled.
-- ============================================================

create extension if not exists pgcrypto;
create extension if not exists pg_trgm;

-- ------------------------------------------------------------
-- Updated-at helper
-- ------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.apply_trigger(tbl text)
returns void
language plpgsql
as $$
begin
  execute format('
    drop trigger if exists trg_%1$s_updated on public.%1$I;
    create trigger trg_%1$s_updated
    before update on public.%1$I
    for each row execute function public.set_updated_at();', tbl);
end;
$$;

-- usage: select public.apply_trigger('<table>');

-- ------------------------------------------------------------
-- ORGANIZATION / BRANCHES (multi-branch ready)
-- ------------------------------------------------------------
create table if not exists public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  branch_count int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.organizations enable row level security;

create table if not exists public.branches (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id),
  name text not null,
  address text,
  phone text,
  email text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.branches enable row level security;

-- ------------------------------------------------------------
-- PROFILES (ties auth.users to app roles/branch)
-- ------------------------------------------------------------
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  branch_id uuid references public.branches(id),
  employee_id uuid,
  full_name text not null default '',
  role text not null default 'staff',
  phone text,
  email text,
  avatar_url text,
  is_active boolean not null default true,
  last_login_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_role_check check (role in ('owner','manager','pharmacist','cashier','inventory_manager','staff'))
);
alter table public.profiles enable row level security;

-- auto-create profile on signup
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_branch uuid;
begin
  select id into v_branch from public.branches where is_active order by created_at limit 1;
  insert into public.profiles (id, branch_id, full_name, role, email)
  values (
    new.id,
    v_branch,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    'staff',
    new.email
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

do $$
begin
  if exists (select 1 from pg_namespace where nspname = 'auth') then
    create or replace trigger on_auth_user_created
      after insert on auth.users
      for each row execute function public.handle_new_user();
  end if;
end $$;

-- ------------------------------------------------------------
-- RBAC catalog
-- ------------------------------------------------------------
create table if not exists public.roles (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  description text,
  created_at timestamptz not null default now()
);
alter table public.roles enable row level security;

create table if not exists public.permissions (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  category text,
  description text,
  created_at timestamptz not null default now()
);
alter table public.permissions enable row level security;

create table if not exists public.role_permissions (
  role_id uuid not null references public.roles(id) on delete cascade,
  permission_id uuid not null references public.permissions(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (role_id, permission_id)
);
alter table public.role_permissions enable row level security;

create table if not exists public.user_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  branch_id uuid references public.branches(id),
  logged_in_at timestamptz not null default now(),
  logged_out_at timestamptz,
  ip text,
  user_agent text
);
alter table public.user_sessions enable row level security;

-- ------------------------------------------------------------
-- EMPLOYEES + ATTENDANCE
-- ------------------------------------------------------------
create table if not exists public.employees (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid references public.branches(id),
  employee_code text unique not null,
  full_name text not null,
  phone text,
  email text,
  position text,
  role text not null default 'staff',
  status text not null default 'active'
    check (status in ('active','inactive','terminated')),
  date_joined date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.employees enable row level security;

create table if not exists public.attendance (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references public.employees(id),
  branch_id uuid references public.branches(id),
  work_date date not null default current_date,
  check_in timestamptz,
  check_out timestamptz,
  duration_minutes int,
  status text not null default 'present'
    check (status in ('present','late','absent','on_leave')),
  notes text,
  created_at timestamptz not null default now()
);
alter table public.attendance enable row level security;
create index idx_attendance_employee_date on public.attendance(employee_id, work_date);
create unique index idx_attendance_open on public.attendance(employee_id) where check_out is null;

-- ------------------------------------------------------------
-- CATALOG
-- ------------------------------------------------------------
create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid references public.branches(id),
  name text not null,
  description text,
  parent_id uuid references public.categories(id),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.categories enable row level security;

create table if not exists public.suppliers (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid references public.branches(id),
  name text not null,
  company text,
  phone text,
  email text,
  address text,
  contact_person text,
  tax_id text,
  notes text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.suppliers enable row level security;

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid references public.branches(id),
  sku text not null,
  barcode text,
  name text not null,
  generic_name text,
  brand text,
  category_id uuid references public.categories(id),
  description text,
  dosage_form text,
  strength text,
  unit text,
  pack_size text,
  purchase_price numeric(14,2) not null default 0 check (purchase_price >= 0),
  selling_price numeric(14,2) not null default 0 check (selling_price >= 0),
  wholesale_price numeric(14,2) not null default 0 check (wholesale_price >= 0),
  min_stock_level numeric(14,2) not null default 0 check (min_stock_level >= 0),
  reorder_level numeric(14,2) not null default 0 check (reorder_level >= 0),
  uses_batches boolean not null default true,
  is_rx boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint products_branch_sku_unique unique (branch_id, sku)
);
alter table public.products enable row level security;
create index idx_products_barcode on public.products(barcode);
create index idx_products_name on public.products using gin (name gin_trgm_ops);
create index idx_products_category on public.products(category_id);

-- ------------------------------------------------------------
-- BATCHES + INVENTORY + STOCK MOVEMENTS
-- ------------------------------------------------------------
create table if not exists public.product_batches (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id),
  branch_id uuid references public.branches(id),
  batch_number text not null,
  purchase_date date,
  manufactured_date date,
  expiry_date date,
  qty_received numeric(14,2) not null default 0 check (qty_received >= 0),
  qty_remaining numeric(14,2) not null default 0 check (qty_remaining >= 0),
  purchase_price numeric(14,2) not null default 0 check (purchase_price >= 0),
  supplier_id uuid references public.suppliers(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.product_batches enable row level security;
create index idx_batches_product_expiry on public.product_batches(product_id, expiry_date);
create index idx_batches_remaining on public.product_batches(qty_remaining) where qty_remaining > 0;

create table if not exists public.inventory (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id),
  branch_id uuid references public.branches(id),
  quantity numeric(14,2) not null default 0 check (quantity >= 0),
  reserved numeric(14,2) not null default 0 check (reserved >= 0),
  stock_value numeric(14,2) not null default 0 check (stock_value >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint inventory_unique unique (product_id, branch_id)
);
alter table public.inventory enable row level security;
create or replace function public.inventory_available() returns numeric
language sql immutable as $$ select 0 $$; -- placeholder; UI computes quantity - reserved

create table if not exists public.stock_movements (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id),
  batch_id uuid references public.product_batches(id),
  branch_id uuid references public.branches(id),
  quantity numeric(14,2) not null, -- signed: +in / -out
  previous_qty numeric(14,2),
  new_qty numeric(14,2),
  movement_type text not null
    check (movement_type in ('purchase','sale','return','adjustment','damage','expired','disposal','transfer','correction')),
  user_id uuid references auth.users(id),
  reason text,
  reference_type text,
  reference_id uuid,
  created_at timestamptz not null default now()
);
alter table public.stock_movements enable row level security;
create index idx_movements_product on public.stock_movements(product_id, created_at);
create index idx_movements_batch on public.stock_movements(batch_id);
create index idx_movements_reference on public.stock_movements(reference_type, reference_id);

-- ------------------------------------------------------------
-- PURCHASES
-- ------------------------------------------------------------
create table if not exists public.purchases (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid references public.branches(id),
  supplier_id uuid references public.suppliers(id),
  purchase_number text unique not null,
  purchase_date date not null default current_date,
  status text not null default 'draft'
    check (status in ('draft','ordered','partially_received','received','cancelled')),
  subtotal numeric(14,2) not null default 0 check (subtotal >= 0),
  discount numeric(14,2) not null default 0 check (discount >= 0),
  tax numeric(14,2) not null default 0 check (tax >= 0),
  total numeric(14,2) not null default 0 check (total >= 0),
  notes text,
  created_by uuid references auth.users(id),
  approved_by uuid references auth.users(id),
  received_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.purchases enable row level security;

create table if not exists public.purchase_items (
  id uuid primary key default gen_random_uuid(),
  purchase_id uuid not null references public.purchases(id) on delete cascade,
  product_id uuid not null references public.products(id),
  quantity numeric(14,2) not null check (quantity > 0),
  unit_cost numeric(14,2) not null default 0 check (unit_cost >= 0),
  discount numeric(14,2) not null default 0 check (discount >= 0),
  tax numeric(14,2) not null default 0 check (tax >= 0),
  line_total numeric(14,2) not null default 0 check (line_total >= 0),
  qty_received numeric(14,2) not null default 0 check (qty_received >= 0),
  created_at timestamptz not null default now()
);
alter table public.purchase_items enable row level security;
create index idx_purchase_items_purchase on public.purchase_items(purchase_id);

-- ------------------------------------------------------------
-- CUSTOMERS
-- ------------------------------------------------------------
create table if not exists public.customers (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid references public.branches(id),
  customer_code text,
  full_name text not null,
  phone text,
  email text,
  address text,
  notes text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.customers enable row level security;

create table if not exists public.customer_balances (
  customer_id uuid primary key references public.customers(id) on delete cascade,
  outstanding numeric(14,2) not null default 0 check (outstanding >= 0),
  updated_at timestamptz not null default now()
);
alter table public.customer_balances enable row level security;

-- ------------------------------------------------------------
-- SALES
-- ------------------------------------------------------------
create table if not exists public.sales (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid references public.branches(id),
  sale_number text unique not null,
  customer_id uuid references public.customers(id),
  cashier_id uuid references auth.users(id),
  total numeric(14,2) not null default 0 check (total >= 0),
  discount numeric(14,2) not null default 0 check (discount >= 0),
  tax numeric(14,2) not null default 0 check (tax >= 0),
  payment_method text not null default 'cash',
  amount_paid numeric(14,2) not null default 0 check (amount_paid >= 0),
  change_amount numeric(14,2) not null default 0 check (change_amount >= 0),
  status text not null default 'active' check (status in ('active','voided')),
  void_reason text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.sales enable row level security;

create table if not exists public.sale_items (
  id uuid primary key default gen_random_uuid(),
  sale_id uuid not null references public.sales(id) on delete cascade,
  product_id uuid not null references public.products(id),
  batch_id uuid references public.product_batches(id),
  quantity numeric(14,2) not null check (quantity > 0),
  unit_price numeric(14,2) not null check (unit_price >= 0),
  discount numeric(14,2) not null default 0 check (discount >= 0),
  cost numeric(14,2) not null default 0 check (cost >= 0),
  line_total numeric(14,2) not null default 0 check (line_total >= 0),
  created_at timestamptz not null default now()
);
alter table public.sale_items enable row level security;

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  sale_id uuid references public.sales(id),
  customer_id uuid references public.customers(id),
  branch_id uuid references public.branches(id),
  amount numeric(14,2) not null check (amount >= 0),
  method text not null default 'cash',
  reference text,
  received_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);
alter table public.payments enable row level security;

-- ------------------------------------------------------------
-- RETURNS / REFUNDS
-- ------------------------------------------------------------
create table if not exists public.returns (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid references public.branches(id),
  sale_id uuid not null references public.sales(id),
  return_number text unique not null,
  customer_id uuid references public.customers(id),
  total_refund numeric(14,2) not null default 0 check (total_refund >= 0),
  reason text,
  status text not null default 'processed',
  processed_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.returns enable row level security;

create table if not exists public.return_items (
  id uuid primary key default gen_random_uuid(),
  return_id uuid not null references public.returns(id) on delete cascade,
  product_id uuid not null references public.products(id),
  batch_id uuid references public.product_batches(id),
  quantity numeric(14,2) not null check (quantity > 0),
  unit_refund numeric(14,2) not null check (unit_refund >= 0),
  line_refund numeric(14,2) not null default 0 check (line_refund >= 0),
  created_at timestamptz not null default now()
);
alter table public.return_items enable row level security;

-- ------------------------------------------------------------
-- INVOICES
-- ------------------------------------------------------------
create table if not exists public.invoices (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid references public.branches(id),
  sale_id uuid references public.sales(id),
  invoice_number text unique not null,
  customer_id uuid references public.customers(id),
  issue_date date not null default current_date,
  due_date date,
  subtotal numeric(14,2) not null default 0 check (subtotal >= 0),
  discount numeric(14,2) not null default 0 check (discount >= 0),
  tax numeric(14,2) not null default 0 check (tax >= 0),
  total numeric(14,2) not null default 0 check (total >= 0),
  amount_paid numeric(14,2) not null default 0 check (amount_paid >= 0),
  balance numeric(14,2) not null default 0 check (balance >= 0),
  status text not null default 'open' check (status in ('open','paid','partial','voided')),
  printed_count int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.invoices enable row level security;

create table if not exists public.invoice_items (
  id uuid primary key default gen_random_uuid(),
  invoice_id uuid not null references public.invoices(id) on delete cascade,
  product_id uuid references public.products(id),
  quantity numeric(14,2) not null check (quantity > 0),
  unit_price numeric(14,2) not null check (unit_price >= 0),
  discount numeric(14,2) not null default 0 check (discount >= 0),
  line_total numeric(14,2) not null default 0 check (line_total >= 0),
  created_at timestamptz not null default now()
);
alter table public.invoice_items enable row level security;

create table if not exists public.invoice_payments (
  id uuid primary key default gen_random_uuid(),
  invoice_id uuid not null references public.invoices(id) on delete cascade,
  amount numeric(14,2) not null check (amount >= 0),
  method text not null default 'cash',
  received_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);
alter table public.invoice_payments enable row level security;

-- ------------------------------------------------------------
-- EXPENSES
-- ------------------------------------------------------------
create table if not exists public.expense_categories (
  id uuid primary key default gen_random_uuid(),
  name text unique not null,
  description text,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);
alter table public.expense_categories enable row level security;

create table if not exists public.expenses (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid references public.branches(id),
  category_id uuid not null references public.expense_categories(id),
  description text not null,
  amount numeric(14,2) not null check (amount >= 0),
  payment_method text not null default 'cash',
  expense_date date not null default current_date,
  recorded_by uuid references auth.users(id),
  attachment_url text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.expenses enable row level security;

-- ------------------------------------------------------------
-- NOTIFICATIONS
-- ------------------------------------------------------------
create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid references public.branches(id),
  recipient_id uuid references auth.users(id), -- null = broadcast
  type text not null
    check (type in ('low_stock','expiring','expired','purchase_pending','customer_balance','system')),
  title text not null,
  body text,
  severity text not null default 'info' check (severity in ('info','warning','critical')),
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);
alter table public.notifications enable row level security;
create index idx_notifications_recipient on public.notifications(recipient_id, is_read);

-- ------------------------------------------------------------
-- AUDIT LOGS
-- ------------------------------------------------------------
create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id),
  branch_id uuid references public.branches(id),
  action text not null,
  entity text,
  entity_id uuid,
  before_data jsonb,
  after_data jsonb,
  ip text,
  user_agent text,
  metadata jsonb,
  created_at timestamptz not null default now()
);
alter table public.audit_logs enable row level security;
create index idx_audit_entity on public.audit_logs(entity, entity_id);
create index idx_audit_created on public.audit_logs(created_at desc);

-- ------------------------------------------------------------
-- SETTINGS
-- ------------------------------------------------------------
create table if not exists public.pharmacy_settings (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null unique references public.branches(id),
  pharmacy_name text not null default 'My Pharmacy',
  logo_url text,
  address text,
  phone text,
  email text,
  business_id text,
  currency text not null default 'GHS',
  timezone text not null default 'Africa/Accra',
  date_format text not null default 'dd/MM/yyyy',
  invoice_prefix text not null default 'INV-',
  invoice_next_number bigint not null default 1,
  receipt_width_mm int not null default 80,
  low_stock_threshold numeric(14,2) not null default 10,
  expiry_warning_days int not null default 30,
  fefo_enabled boolean not null default true,
  prevent_negative_stock boolean not null default true,
  payment_methods jsonb not null default '["cash","mobile_money","card","bank","credit"]',
  tax_rate numeric(14,2) not null default 0,
  updated_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.pharmacy_settings enable row level security;

-- ------------------------------------------------------------
-- Helper functions (auth/role helpers)
-- ------------------------------------------------------------
create or replace function public.app_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select role from public.profiles where id = auth.uid();
$$;

create or replace function public.app_branch()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select branch_id from public.profiles where id = auth.uid();
$$;

create or replace function public.has_permission(p_code text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles pr
    join public.role_permissions rp on rp.role_id = (select r.id from public.roles r where r.name = pr.role)
    join public.permissions p on p.id = rp.permission_id
    where pr.id = auth.uid() and p.code = p_code
  );
$$;

create or replace function public.login_context()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  with me as (
    select * from public.profiles where id = auth.uid()
  ),
  perms as (
    select coalesce(array_agg(p.code order by p.code), '{}'::text[]) as codes
    from public.profiles pr
    join public.role_permissions rp on rp.role_id = (select r.id from public.roles r where r.name = pr.role)
    join public.permissions p on p.id = rp.permission_id
    where pr.id = auth.uid()
  ),
  settings as (
    select s.* from public.pharmacy_settings s
    join public.profiles pr on pr.branch_id = s.branch_id
    where pr.id = auth.uid()
  )
  select jsonb_build_object(
    'profile', (select to_jsonb(*) from me),
    'permissions', (select codes from perms),
    'settings', (select to_jsonb(*) from settings)
  );
$$;

-- ------------------------------------------------------------
-- Invoice number generator (branch-scoped, race-safe)
-- ------------------------------------------------------------
create or replace function public.next_invoice_number()
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_branch uuid := public.app_branch();
  v_prefix text;
  v_seq bigint;
  v_ret text;
begin
  if v_branch is null then
    raise exception 'no branch assigned to current user';
  end if;

  perform pg_advisory_xact_lock(hashtext('invoice_num_' || v_branch::text));

  select invoice_prefix, invoice_next_number into v_prefix, v_seq
  from public.pharmacy_settings where branch_id = v_branch;

  if v_seq is null then
    v_prefix := 'INV-';
    v_seq := 1;
    insert into public.pharmacy_settings (branch_id, invoice_prefix, invoice_next_number)
    values (v_branch, v_prefix, 2);
  else
    update public.pharmacy_settings
    set invoice_next_number = invoice_next_number + 1
    where branch_id = v_branch;
  end if;

  v_ret := v_prefix || to_char(v_seq, 'FM000000');
  return v_ret;
end;
$$;

-- ------------------------------------------------------------
-- Stock movement -> inventory aggregate sync
-- Every stock change MUST go through stock_movements; this
-- keeps the inventory snapshot consistent and auditable.
-- ------------------------------------------------------------
create or replace function public.sync_inventory_from_movement()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_value numeric(14,2);
begin
  select coalesce(sum(b.qty_remaining * b.purchase_price), 0) into v_value
  from public.product_batches b
  where b.product_id = new.product_id and b.branch_id = new.branch_id;

  insert into public.inventory (product_id, branch_id, quantity, stock_value)
  values (new.product_id, new.branch_id, new.quantity, v_value)
  on conflict (product_id, branch_id)
  do update set
    quantity = inventory.quantity + new.quantity,
    stock_value = v_value,
    updated_at = now();

  return new;
end;
$$;

create or replace trigger trg_inventory_sync
after insert on public.stock_movements
for each row execute function public.sync_inventory_from_movement();

-- Also recompute inventory value when a batch changes (purchase price edits)
create or replace function public.sync_inventory_value_from_batch()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_value numeric(14,2);
begin
  if tg_op = 'DELETE' then return old; end if;
  select coalesce(sum(b.qty_remaining * b.purchase_price), 0) into v_value
  from public.product_batches b
  where b.product_id = new.product_id
    and b.branch_id = new.branch_id;

  update public.inventory inv
  set stock_value = v_value, updated_at = now()
  where inv.product_id = new.product_id
    and inv.branch_id = new.branch_id;

  return new;
end;
$$;

create or replace trigger trg_batch_value_sync
after insert or update of qty_remaining, purchase_price on public.product_batches
for each row execute function public.sync_inventory_value_from_batch();

-- ------------------------------------------------------------
-- Seed: roles + permissions
-- ------------------------------------------------------------
insert into public.roles (name, description) values
  ('owner', 'Full access across the pharmacy'),
  ('manager', 'Operational management'),
  ('pharmacist', 'Pharmacy workflows and sales'),
  ('cashier', 'POS, sales, receipts'),
  ('inventory_manager', 'Stock, batches, purchases'),
  ('staff', 'Restricted permissions')
on conflict (name) do nothing;

insert into public.permissions (code, category, description) values
  ('dashboard.view', 'Dashboard', 'View dashboard'),
  ('sales.create', 'Sales', 'Create/complete sales'),
  ('sales.view', 'Sales', 'View sales'),
  ('sales.view_own', 'Sales', 'View own sales'),
  ('sales.void', 'Sales', 'Void a sale'),
  ('sales.refund', 'Sales', 'Process refunds/returns'),
  ('invoice.view', 'Invoices', 'View invoices'),
  ('invoice.print', 'Invoices', 'Print invoices and receipts'),
  ('invoice.void', 'Invoices', 'Void invoices'),
  ('product.view', 'Products', 'View products'),
  ('product.create', 'Products', 'Create products'),
  ('product.update', 'Products', 'Update products'),
  ('inventory.view', 'Inventory', 'View inventory'),
  ('inventory.adjust', 'Inventory', 'Adjust stock'),
  ('inventory.receive', 'Inventory', 'Receive stock'),
  ('inventory.transfer', 'Inventory', 'Transfer stock'),
  ('supplier.view', 'Suppliers', 'View suppliers'),
  ('supplier.manage', 'Suppliers', 'Manage suppliers'),
  ('purchase.view', 'Purchases', 'View purchases'),
  ('purchase.create', 'Purchases', 'Create purchase orders'),
  ('purchase.receive', 'Purchases', 'Receive purchase orders'),
  ('customer.view', 'Customers', 'View customers'),
  ('customer.manage', 'Customers', 'Create/update customers'),
  ('expense.view', 'Expenses', 'View expenses'),
  ('expense.create', 'Expenses', 'Record expenses'),
  ('expense.manage', 'Expenses', 'Manage expense categories'),
  ('employee.view', 'Employees', 'View employees'),
  ('employee.manage', 'Employees', 'Manage employees'),
  ('attendance.self', 'Attendance', 'Self check-in/out'),
  ('attendance.manage', 'Attendance', 'Manage attendance'),
  ('report.view', 'Reports', 'View reports'),
  ('report.financial', 'Reports', 'View financial reports'),
  ('settings.manage', 'Settings', 'Manage settings'),
  ('audit.view', 'Audit', 'View audit logs'),
  ('notification.view', 'Notifications', 'View notifications'),
  ('users.manage', 'Users', 'Manage users and roles')
on conflict (code) do nothing;

-- permission grants per role
insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r cross join public.permissions p
where r.name = 'owner'
on conflict do nothing;

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p on p.code in (
  'dashboard.view','sales.view','invoice.view','invoice.print',
  'product.view','product.create','product.update',
  'inventory.view','inventory.receive','inventory.transfer',
  'supplier.view','supplier.manage','purchase.view','purchase.create','purchase.receive',
  'customer.view','customer.manage','expense.view','expense.create','expense.manage',
  'employee.view','attendance.self','attendance.manage',
  'report.view','report.financial','notification.view','audit.view'
)
where r.name = 'manager'
on conflict do nothing;

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p on p.code in (
  'dashboard.view','sales.create','sales.view','invoice.view','invoice.print',
  'product.view','inventory.view','customer.view','customer.manage',
  'attendance.self','report.view','notification.view'
)
where r.name = 'pharmacist'
on conflict do nothing;

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p on p.code in (
  'sales.create','sales.view_own','invoice.view','invoice.print',
  'product.view','inventory.view','customer.view','customer.manage',
  'attendance.self','notification.view'
)
where r.name = 'cashier'
on conflict do nothing;

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p on p.code in (
  'product.view','product.create','product.update',
  'inventory.view','inventory.adjust','inventory.receive','inventory.transfer',
  'supplier.view','supplier.manage','purchase.view','purchase.create','purchase.receive',
  'expense.view','attendance.self','notification.view'
)
where r.name = 'inventory_manager'
on conflict do nothing;

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p on p.code in (
  'product.view','inventory.view','attendance.self','notification.view'
)
where r.name = 'staff'
on conflict do nothing;

-- ------------------------------------------------------------
-- RLS policies
-- ------------------------------------------------------------
-- profiles
create policy "user can read own profile" on public.profiles
  for select using (id = auth.uid());
create policy "owner and manager can read branch profiles" on public.profiles
  for select using (public.app_role() in ('owner','manager') and (branch_id = public.app_branch() or public.app_role() = 'owner'));
create policy "user can update own profile" on public.profiles
  for update using (id = auth.uid()) with check (
    -- prevent self-service privilege escalation: role stays unchanged
    id = auth.uid()
    and role = public.app_role()
  );
create policy "owner and manager can update branch profiles" on public.profiles
  for update using (public.app_role() in ('owner','manager'))
  with check (public.app_role() in ('owner','manager'));

-- organizations / branches
create policy "authenticated can read orgs" on public.organizations
  for select to authenticated using (true);
create policy "authenticated can read branches" on public.branches
  for select to authenticated using (true);

-- roles / permissions catalogs readable by authenticated
create policy "authenticated can read roles" on public.roles
  for select to authenticated using (true);
create policy "authenticated can read permissions" on public.permissions
  for select to authenticated using (true);
create policy "authenticated can read role_permissions" on public.role_permissions
  for select to authenticated using (true);

-- employees
create policy "owner/manager manage employees" on public.employees
  for all using (public.app_role() in ('owner','manager')) with check (public.app_role() in ('owner','manager'));
create policy "staff can view employees" on public.employees
  for select using (public.app_role() in ('pharmacist','cashier','inventory_manager','staff'));

-- attendance
create policy "owner/manager manage attendance" on public.attendance
  for all using (public.app_role() in ('owner','manager')) with check (public.app_role() in ('owner','manager'));
create policy "own attendance self-service" on public.attendance
  for insert with check (
    public.app_role() in ('pharmacist','cashier','inventory_manager','staff')
    and employee_id = (select employee_id from public.profiles where id = auth.uid())
  );
create policy "staff can view attendance" on public.attendance
  for select using (public.app_role() in ('pharmacist','cashier','inventory_manager','staff'));

-- categories
create policy "inventory roles manage categories" on public.categories
  for all using (public.app_role() in ('owner','manager','inventory_manager')) with check (public.app_role() in ('owner','manager','inventory_manager'));
create policy "all staff view categories" on public.categories
  for select using (public.app_role() in ('owner','manager','pharmacist','cashier','inventory_manager','staff'));

-- suppliers
create policy "inventory roles manage suppliers" on public.suppliers
  for all using (public.app_role() in ('owner','manager','inventory_manager')) with check (public.app_role() in ('owner','manager','inventory_manager'));
create policy "all staff view suppliers" on public.suppliers
  for select using (public.app_role() in ('owner','manager','pharmacist','cashier','inventory_manager','staff'));

-- products
create policy "inventory roles manage products" on public.products
  for all using (public.app_role() in ('owner','manager','inventory_manager')) with check (public.app_role() in ('owner','manager','inventory_manager'));
create policy "all staff view products" on public.products
  for select using (public.app_role() in ('owner','manager','pharmacist','cashier','inventory_manager','staff'));

-- product_batches: writes ONLY via stock RPCs (definer); read for staff with inventory.view
create policy "all staff view batches" on public.product_batches
  for select using (public.app_role() in ('owner','manager','pharmacist','cashier','inventory_manager','staff'));

-- inventory: reads for staff; writes only through stock_movements trigger + RPCs
create policy "all staff view inventory" on public.inventory
  for select using (public.app_role() in ('owner','manager','pharmacist','cashier','inventory_manager','staff'));

-- stock_movements: insert-only for definer RPCs; view restricted
create policy "owner/manager/inventory view movements" on public.stock_movements
  for select using (public.app_role() in ('owner','manager','inventory_manager'));
-- stock_movements inserts happen ONLY inside SECURITY DEFINER RPCs
-- (complete_sale / receive_purchase / process_return / adjust_stock).

-- purchases
create policy "inventory roles manage purchases" on public.purchases
  for all using (public.app_role() in ('owner','manager','inventory_manager')) with check (public.app_role() in ('owner','manager','inventory_manager'));
create policy "staff view purchases" on public.purchases
  for select using (public.app_role() in ('pharmacist','cashier'));
create policy "inventory roles manage purchase items" on public.purchase_items
  for all using (public.app_role() in ('owner','manager','inventory_manager')) with check (public.app_role() in ('owner','manager','inventory_manager'));
create policy "staff view purchase items" on public.purchase_items
  for select using (public.app_role() in ('pharmacist','cashier'));

-- customers
create policy "staff manage customers" on public.customers
  for all using (public.app_role() in ('owner','manager','cashier','pharmacist')) with check (public.app_role() in ('owner','manager','cashier','pharmacist'));
create policy "customers visible to all staff" on public.customers
  for select using (public.app_role() in ('owner','manager','pharmacist','cashier','inventory_manager','staff'));

create policy "owner/manager view balances" on public.customer_balances
  for select using (public.app_role() in ('owner','manager','cashier','pharmacist'));

-- sales: writes happen ONLY inside the SECURITY DEFINER complete_sale RPC
create policy "staff view sales" on public.sales
  for select using (public.app_role() in ('owner','manager','pharmacist','cashier'));

create policy "staff view sale items" on public.sale_items
  for select using (public.app_role() in ('owner','manager','pharmacist','cashier','inventory_manager'));

create policy "staff view payments" on public.payments
  for select using (public.app_role() in ('owner','manager','pharmacist','cashier'));

-- returns: writes happen ONLY inside SECURITY DEFINER RPCs
create policy "view returns" on public.returns
  for select using (public.app_role() in ('owner','manager','pharmacist','cashier','inventory_manager'));
create policy "view return items" on public.return_items
  for select using (public.app_role() in ('owner','manager','pharmacist','cashier','inventory_manager'));

-- invoices
create policy "view invoices" on public.invoices
  for select using (public.app_role() in ('owner','manager','pharmacist','cashier'));
create policy "manage invoices" on public.invoices
  for all using (public.app_role() in ('owner','manager')) with check (public.app_role() in ('owner','manager'));
create policy "view invoice items" on public.invoice_items
  for select using (public.app_role() in ('owner','manager','pharmacist','cashier'));
create policy "view invoice payments" on public.invoice_payments
  for select using (public.app_role() in ('owner','manager','pharmacist','cashier'));

-- expenses
create policy "owner/manager manage expenses" on public.expenses
  for all using (public.app_role() in ('owner','manager')) with check (public.app_role() in ('owner','manager'));
create policy "staff view expenses" on public.expenses
  for select using (public.app_role() in ('pharmacist','cashier','inventory_manager'));
create policy "manage expense categories" on public.expense_categories
  for all using (public.app_role() in ('owner','manager')) with check (public.app_role() in ('owner','manager'));
create policy "view expense categories" on public.expense_categories
  for select using (public.app_role() in ('pharmacist','cashier','inventory_manager'));

-- notifications
create policy "view notifications" on public.notifications
  for select using (public.app_role() in ('owner','manager','pharmacist','cashier','inventory_manager','staff'));
create policy "system writes notifications" on public.notifications
  for insert with check (public.app_role() in ('owner','manager'));

-- audit logs (read-only for privileged; inserts via definer triggers only)
create policy "view audit logs" on public.audit_logs
  for select using (public.app_role() in ('owner','manager'));

-- settings
create policy "view settings" on public.pharmacy_settings
  for select using (public.app_role() in ('owner','manager','pharmacist','cashier','inventory_manager'));
create policy "owner manages settings" on public.pharmacy_settings
  for all using (public.app_role() = 'owner') with check (public.app_role() = 'owner');

-- sessions (login history)
create policy "view own sessions" on public.user_sessions
  for select using (user_id = auth.uid());
create policy "owner/manager view sessions" on public.user_sessions
  for select using (public.app_role() in ('owner','manager'));

-- ------------------------------------------------------------
-- updated_at triggers
-- ------------------------------------------------------------
select apply_trigger('profiles');
select apply_trigger('organizations');
select apply_trigger('branches');
select apply_trigger('employees');
select apply_trigger('categories');
select apply_trigger('suppliers');
select apply_trigger('products');
select apply_trigger('product_batches');
select apply_trigger('inventory');
select apply_trigger('purchases');
select apply_trigger('customers');
select apply_trigger('customer_balances');
select apply_trigger('sales');
select apply_trigger('returns');
select apply_trigger('expenses');
select apply_trigger('pharmacy_settings');
select apply_trigger('attendance');

-- grants
grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant select on all tables in schema public to anon;
grant execute on all functions in schema public to anon, authenticated;

-- internal/trigger helpers must not be callable by clients
revoke execute on function public.set_updated_at() from anon, authenticated;
revoke execute on function public.apply_trigger(text) from anon, authenticated;
revoke execute on function public.handle_new_user() from anon, authenticated;
revoke execute on function public.sync_inventory_from_movement() from anon, authenticated;
revoke execute on function public.sync_inventory_value_from_batch() from anon, authenticated;
revoke execute on function public.inventory_available() from anon, authenticated;
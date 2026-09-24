-- ============================================================
-- PHARMACY MANAGEMENT SYSTEM — Development/Demo Seed Data
-- Run only in dev/staging. Never in production.
-- ============================================================

-- Org + Main branch
insert into public.organizations (id, name, branch_count)
values ('00000000-0000-0000-0000-000000000001', 'Demo Pharmacy Group', 1)
on conflict (id) do nothing;

insert into public.branches (id, org_id, name, address, phone, email, is_active)
values (
  '00000000-0000-0000-0000-000000000101',
  '00000000-0000-0000-0000-000000000001',
  'Main Branch',
  '123 Independence Ave, Accra',
  '+233 55 000 0000',
  'info@demopharmacy.com',
  true
)
on conflict (id) do nothing;

-- Settings
insert into public.pharmacy_settings (
  branch_id, pharmacy_name, currency, timezone, invoice_prefix, invoice_next_number,
  low_stock_threshold, expiry_warning_days, payment_methods, tax_rate
) values (
  '00000000-0000-0000-0000-000000000101',
  'Demo Pharmacy',
  'GHS',
  'Africa/Accra',
  'INV-',
  1,
  10,
  30,
  '["cash","mobile_money","card","bank","credit"]',
  0
)
on conflict (branch_id) do nothing;

-- Expense categories
insert into public.expense_categories (name, description) values
  ('Rent', 'Premises rent'),
  ('Electricity', 'Electricity bills'),
  ('Water', 'Water bills'),
  ('Internet', 'Internet and data'),
  ('Salaries', 'Staff salaries'),
  ('Transport', 'Transport and logistics'),
  ('Maintenance', 'Repairs and maintenance'),
  ('Supplies', 'Stationery and supplies'),
  ('Marketing', 'Marketing and advertising'),
  ('Other', 'Other expenses')
on conflict (name) do nothing;

-- Suppliers
insert into public.suppliers (id, branch_id, name, company, phone, email, address, contact_person, tax_id, is_active) values
  ('00000000-0000-0000-0000-000000000201', '00000000-0000-0000-0000-000000000101', 'Ernest Chemists', 'Ernest Chemists Ltd', '+233 24 111 1111', 'sales@ernestchemists.com', 'Accra', 'Kwame Mensah', 'GH-TIN-0001', true),
  ('00000000-0000-0000-0000-000000000202', '00000000-0000-0000-0000-000000000101', 'PharmaVision', 'PharmaVision Distributors', '+233 20 222 2222', 'orders@pharmavision.com', 'Tema', 'Ama Serwaa', 'GH-TIN-0002', true),
  ('00000000-0000-0000-0000-000000000203', '00000000-0000-0000-0000-000000000101', 'MedPlus Wholesale', 'MedPlus Ltd', '+233 26 333 3333', 'info@medplus.com', 'Kumasi', 'Yaw Osei', 'GH-TIN-0003', true)
on conflict (id) do nothing;

-- Categories
insert into public.categories (id, branch_id, name, description, is_active) values
  ('00000000-0000-0000-0000-000000000301', '00000000-0000-0000-0000-000000000101', 'Analgesics', 'Pain relief', true),
  ('00000000-0000-0000-0000-000000000302', '00000000-0000-0000-0000-000000000101', 'Antibiotics', 'Antibacterial medicines', true),
  ('00000000-0000-0000-0000-000000000303', '00000000-0000-0000-0000-000000000101', 'Antimalarials', 'Malaria treatment', true),
  ('00000000-0000-0000-0000-000000000304', '00000000-0000-0000-0000-000000000101', 'Cough & Cold', 'Cold and flu', true),
  ('00000000-0000-0000-0000-000000000305', '00000000-0000-0000-0000-000000000101', 'Vitamins & Supplements', 'Dietary supplements', true),
  ('00000000-0000-0000-0000-000000000306', '00000000-0000-0000-0000-000000000101', 'First Aid', 'First aid supplies', true),
  ('00000000-0000-0000-0000-000000000307', '00000000-0000-0000-0000-000000000101', 'Hypertension', 'Blood pressure medicine', true),
  ('00000000-0000-0000-0000-000000000308', '00000000-0000-0000-0000-000000000101', 'Diabetes', 'Diabetes management', true),
  ('00000000-0000-0000-0000-000000000309', '00000000-0000-0000-0000-000000000101', 'Other', 'Miscellaneous', true)
on conflict (id) do nothing;

-- Products
insert into public.products (
  id, branch_id, sku, barcode, name, generic_name, brand, category_id, description,
  dosage_form, strength, unit, pack_size, purchase_price, selling_price, wholesale_price,
  min_stock_level, reorder_level, uses_batches, is_rx, is_active
) values
  ('00000000-0000-0000-0000-000000000401', '00000000-0000-0000-0000-000000000101', 'PARA-500-100', '6001001001', 'Paracetamol 500mg', 'Paracetamol', 'GPO', '00000000-0000-0000-0000-000000000301', 'Pain and fever relief', 'Tablet', '500mg', 'tab', '100 tabs', 2.50, 5.00, 4.00, 50, 100, true, false, true),
  ('00000000-0000-0000-0000-000000000402', '00000000-0000-0000-0000-000000000101', 'IBU-400-100', '6001001002', 'Ibuprofen 400mg', 'Ibuprofen', 'Premier', '00000000-0000-0000-0000-000000000301', 'Anti-inflammatory', 'Tablet', '400mg', 'tab', '100 tabs', 4.00, 8.00, 6.50, 40, 80, true, false, true),
  ('00000000-0000-0000-0000-000000000403', '00000000-0000-0000-0000-000000000101', 'AMOX-250-100', '6001001003', 'Amoxicillin 250mg', 'Amoxicillin', 'Antibio', '00000000-0000-0000-0000-000000000302', 'Antibiotic', 'Capsule', '250mg', 'cap', '100 caps', 9.00, 15.00, 13.00, 30, 60, true, true, true),
  ('00000000-0000-0000-0000-000000000404', '00000000-0000-0000-0000-000000000101', 'ARTE-LUM-80', '6001001004', 'Artemether/Lumefantrine 80/480', 'Artemether/Lumefantrine', 'Greenlife', '00000000-0000-0000-0000-000000000303', 'Malaria treatment', 'Tablet', '80/480mg', 'tab', '6 tabs', 18.00, 28.00, 25.00, 20, 40, true, true, true),
  ('00000000-0000-0000-0000-000000000405', '00000000-0000-0000-0000-000000000101', 'VIC-DRY-200', '6001001005', 'Cough Syrup 200ml', 'Dextromethorphan', 'Prolab', '00000000-0000-0000-0000-000000000304', 'Dry cough relief', 'Syrup', '200ml', 'btl', '1 bottle', 12.00, 22.00, 19.00, 15, 30, true, false, true),
  ('00000000-0000-0000-0000-000000000406', '00000000-0000-0000-0000-000000000101', 'VIT-C-100', '6001001006', 'Vitamin C 1000mg', 'Ascorbic Acid', 'SunAnd', '00000000-0000-0000-0000-000000000305', 'Immune support', 'Effervescent', '1000mg', 'tab', '20 tabs', 6.00, 12.00, 10.00, 25, 50, true, false, true),
  ('00000000-0000-0000-0000-000000000407', '00000000-0000-0000-0000-000000000101', 'AMLO-5-28', '6001001007', 'Amlodipine 5mg', 'Amlodipine', 'Xinjiang', '00000000-0000-0000-0000-000000000307', 'Blood pressure', 'Tablet', '5mg', 'tab', '28 tabs', 3.50, 7.00, 6.00, 30, 60, true, true, true),
  ('00000000-0000-0000-0000-000000000408', '00000000-0000-0000-0000-000000000101', 'METFO-500-100', '6001001008', 'Metformin 500mg', 'Metformin', 'DMD', '00000000-0000-0000-0000-000000000308', 'Diabetes management', 'Tablet', '500mg', 'tab', '100 tabs', 5.00, 10.00, 8.50, 40, 80, true, true, true)
on conflict (id) do nothing;

-- Batches (with varied expiries to exercise FEFO + expiry warnings)
insert into public.product_batches (
  id, product_id, branch_id, batch_number, purchase_date, manufactured_date, expiry_date,
  qty_received, qty_remaining, purchase_price, supplier_id
) values
  ('00000000-0000-0000-0000-000000000501', '00000000-0000-0000-0000-000000000401', '00000000-0000-0000-0000-000000000101', 'BP-PARA-A', current_date - 90, current_date - 90, current_date + 400, 200, 150, 2.50, '00000000-0000-0000-0000-000000000201'),
  ('00000000-0000-0000-0000-000000000502', '00000000-0000-0000-0000-000000000401', '00000000-0000-0000-0000-000000000101', 'BP-PARA-B', current_date - 30, current_date - 30, current_date + 700, 200, 200, 2.40, '00000000-0000-0000-0000-000000000202'),
  ('00000000-0000-0000-0000-000000000503', '00000000-0000-0000-0000-000000000403', '00000000-0000-0000-0000-000000000101', 'BP-AMOX-A', current_date - 60, current_date - 60, current_date + 20,  100, 100, 9.00, '00000000-0000-0000-0000-000000000201'),
  ('00000000-0000-0000-0000-000000000504', '00000000-0000-0000-0000-000000000403', '00000000-0000-0000-0000-000000000101', 'BP-AMOX-B', current_date - 10, current_date - 10, current_date + 500, 100, 0,   9.00, '00000000-0000-0000-0000-000000000202'),
  ('00000000-0000-0000-0000-000000000505', '00000000-0000-0000-0000-000000000404', '00000000-0000-0000-0000-000000000101', 'BP-ARTE-A', current_date - 45, current_date - 45, current_date - 5,   100, 25,  18.00,'00000000-0000-0000-0000-000000000203'),
  ('00000000-0000-0000-0000-000000000506', '00000000-0000-0000-0000-000000000406', '00000000-0000-0000-0000-000000000101', 'BP-VITC-A', current_date - 15, current_date - 15, current_date + 300, 100, 80,  6.00, '00000000-0000-0000-0000-000000000203'),
  ('00000000-0000-0000-0000-000000000507', '00000000-0000-0000-0000-000000000407', '00000000-0000-0000-0000-000000000101', 'BP-AMLO-A', current_date - 20, current_date - 20, current_date + 250, 50,  45,  3.50, '00000000-0000-0000-0000-000000000201'),
  ('00000000-0000-0000-0000-000000000508', '00000000-0000-0000-0000-000000000408', '00000000-0000-0000-0000-000000000101', 'BP-MET-A',  current_date - 40, current_date - 40, current_date + 600, 100, 100, 5.00, '00000000-0000-0000-0000-000000000202')
on conflict (id) do nothing;

-- Inventory snapshot (consistent with batches above)
insert into public.inventory (product_id, branch_id, quantity, stock_value) values
  ('00000000-0000-0000-0000-000000000401', '00000000-0000-0000-0000-000000000101', 350, 375.00),
  ('00000000-0000-0000-0000-000000000402', '00000000-0000-0000-0000-000000000101', 0,   0.00),
  ('00000000-0000-0000-0000-000000000403', '00000000-0000-0000-0000-000000000101', 100, 900.00),
  ('00000000-0000-0000-0000-000000000404', '00000000-0000-0000-0000-000000000101', 25,  450.00),
  ('00000000-0000-0000-0000-000000000405', '00000000-0000-0000-0000-000000000101', 0,   0.00),
  ('00000000-0000-0000-0000-000000000406', '00000000-0000-0000-0000-000000000101', 80,  480.00),
  ('00000000-0000-0000-0000-000000000407', '00000000-0000-0000-0000-000000000101', 45,  157.50),
  ('00000000-0000-0000-0000-000000000408', '00000000-0000-0000-0000-000000000101', 100, 500.00)
on conflict (product_id, branch_id) do nothing;

-- Employees
insert into public.employees (id, branch_id, employee_code, full_name, phone, email, position, role, status, date_joined) values
  ('00000000-0000-0000-0000-000000000601', '00000000-0000-0000-0000-000000000101', 'EMP-001', 'Ama Boateng',    '+233 24 000 0001', 'ama@demopharmacy.com', 'General Manager',  'manager',  'active', '2024-01-10'),
  ('00000000-0000-0000-0000-000000000602', '00000000-0000-0000-0000-000000000101', 'EMP-002', 'Kofi Asante',     '+233 24 000 0002', 'kofi@demopharmacy.com',  'Registered Pharmacist', 'pharmacist', 'active', '2024-02-15'),
  ('00000000-0000-0000-0000-000000000603', '00000000-0000-0000-0000-000000000101', 'EMP-003', 'Efua Osei',       '+233 24 000 0003', 'efua@demopharmacy.com',  'Cashier',  'cashier', 'active', '2024-03-01'),
  ('00000000-0000-0000-0000-000000000604', '00000000-0000-0000-0000-000000000101', 'EMP-004', 'Yaw Darko',       '+233 24 000 0004', 'yaw@demopharmacy.com',   'Inventory Manager', 'inventory_manager', 'active', '2024-04-12')
on conflict (id) do nothing;

-- Customers
insert into public.customers (id, branch_id, customer_code, full_name, phone, email, address, notes, is_active) values
  ('00000000-0000-0000-0000-000000000701', '00000000-0000-0000-0000-000000000101', 'CUS-0001', 'Akosua Nyarko',  '+233 24 111 2222', 'akosua@example.com', 'Accra', 'Regular customer', true),
  ('00000000-0000-0000-0000-000000000702', '00000000-0000-0000-0000-000000000101', 'CUS-0002', 'Kwaku Bonsu',    '+233 24 333 4444', 'kwaku@example.com',  'Tema',  '', true),
  ('00000000-0000-0000-0000-000000000703', '00000000-0000-0000-0000-000000000101', 'CUS-0003', 'Nana Adjoa',     '+233 24 555 6666', 'nana@example.com',   'Accra', 'Credit customer', true)
on conflict (id) do nothing;

insert into public.customer_balances (customer_id, outstanding) values
  ('00000000-0000-0000-0000-000000000703', 45.00)
on conflict (customer_id) do nothing;

-- Sample expenses
insert into public.expenses (branch_id, category_id, description, amount, payment_method, expense_date, notes)
select
  '00000000-0000-0000-0000-000000000101',
  c.id,
  d.description,
  d.amount,
  'cash',
  current_date - d.days,
  'Seed data'
from (values
  (25, 1200.00, 'Monthly electricity'),
  (15,  800.00, 'Internet bill'),
  (10, 150.00,  'Packaging supplies'),
  (5,   60.00,  'Transport')
) as d(days, amount, description)
join public.expense_categories c
  on c.name = case d.days when 25 then 'Electricity' when 15 then 'Internet' when 10 then 'Supplies' else 'Transport' end;

-- Sample purchase orders
insert into public.purchases (
  id, branch_id, supplier_id, purchase_number, purchase_date, status, subtotal, tax, total, notes
) values
  ('00000000-0000-0000-0000-000000000801', '00000000-0000-0000-0000-000000000101', '00000000-0000-0000-0000-000000000201', 'PO-20260001', current_date - 90, 'received', 500.00, 0, 500.00, 'Paracetamol stock'),
  ('00000000-0000-0000-0000-000000000802', '00000000-0000-0000-0000-000000000101', '00000000-0000-0000-0000-000000000203', 'PO-20260002', current_date - 30, 'ordered',  600.00, 0, 600.00, 'Antibiotics replenishment')
on conflict (id) do nothing;

insert into public.purchase_items (purchase_id, product_id, quantity, unit_cost, line_total, qty_received) values
  ('00000000-0000-0000-0000-000000000801', '00000000-0000-0000-0000-000000000401', 200, 2.50, 500.00, 200),
  ('00000000-0000-0000-0000-000000000802', '00000000-0000-0000-0000-000000000403',  50, 9.00, 450.00, 0),
  ('00000000-0000-0000-0000-000000000802', '00000000-0000-0000-0000-000000000404',  10, 15.00,150.00, 0)
on conflict do nothing;
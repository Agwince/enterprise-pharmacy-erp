-- =============================================================================
-- MEDIOCARE PHARMACY ERP
-- FINANCE & GENERAL LEDGER  +  HR & PAYROLL
-- Migration: 20260829_mediocare_finance_hr.sql
--
-- HOW TO RUN:  Supabase Dashboard -> SQL Editor -> New query -> paste -> RUN
-- IDEMPOTENT:  safe to run more than once (all statements are IF NOT EXISTS)
-- =============================================================================

create extension if not exists pgcrypto;

-- =============================================================================
-- 1. CHART OF ACCOUNTS
-- =============================================================================
create table if not exists public.chart_of_accounts (
  id            uuid primary key default gen_random_uuid(),
  code          text not null unique,
  name          text not null,
  type          text not null check (type in ('asset','liability','equity','income','expense')),
  category      text,                    -- e.g. 'Current Assets', 'Revenue'
  parent_code   text,
  normal_balance text default 'debit' check (normal_balance in ('debit','credit')),
  is_control    boolean default false,   -- control accounts (bank, VAT, payroll)
  is_active     boolean default true,
  external_ledger text,                  -- mapping to external nominal ledger if used
  created_at    timestamptz default now()
);

-- =============================================================================
-- 2. JOURNALS (double entry)
-- =============================================================================
create table if not exists public.journal_entries (
  id             uuid primary key default gen_random_uuid(),
  entry_no       text unique,
  journal_date   date not null default current_date,
  reference      text,
  memo           text,
  source_module  text default 'manual',   -- pos | procurement | payroll | insurance | manual
  source_id      text,
  branch_id      uuid references public.branches(id) on delete set null,
  status         text default 'posted' check (status in ('draft','posted','reversed')),
  total_debit    numeric(16,2) default 0,
  total_credit   numeric(16,2) default 0,
  created_by     text,
  created_at     timestamptz default now(),
  posted_at      timestamptz default now()
);

create table if not exists public.journal_lines (
  id           uuid primary key default gen_random_uuid(),
  journal_id   uuid not null references public.journal_entries(id) on delete cascade,
  account_code text not null references public.chart_of_accounts(code) on update cascade,
  debit        numeric(16,2) not null default 0,
  credit       numeric(16,2) not null default 0,
  branch_id    uuid references public.branches(id) on delete set null,
  cost_center  text,
  line_memo    text,
  created_at   timestamptz default now()
);

create index if not exists idx_journal_lines_journal on public.journal_lines(journal_id);
create index if not exists idx_journal_lines_account on public.journal_lines(account_code);
create index if not exists idx_journal_entries_date   on public.journal_entries(journal_date desc);

-- =============================================================================
-- 3. SUPPLIERS / CREDITORS (Empty by default, user-entered parameters)
-- =============================================================================
create table if not exists public.suppliers (
  id            uuid primary key default gen_random_uuid(),
  name          text not null,
  code          text,
  kra_pin       text,
  phone         text,
  email         text,
  contact_person text,
  payment_terms text,
  credit_limit  numeric(16,2),
  balance       numeric(16,2) default 0,
  lead_time_days int,
  is_active     boolean default true,
  created_at    timestamptz default now()
);

-- Extensions to existing purchase_orders table (Module 2: LPO & GRN & 3-Way Match)
alter table public.purchase_orders add column if not exists supplier_id uuid references public.suppliers(id) on delete set null;
alter table public.purchase_orders add column if not exists delivery_date date;
alter table public.purchase_orders add column if not exists notes text;
alter table public.purchase_orders add column if not exists approved_by text;
alter table public.purchase_orders add column if not exists approved_at timestamptz;
alter table public.purchase_orders add column if not exists grn_number text;
alter table public.purchase_orders add column if not exists grn_date timestamptz;
alter table public.purchase_orders add column if not exists received_by text;
alter table public.purchase_orders add column if not exists invoice_number text;
alter table public.purchase_orders add column if not exists invoice_amount numeric(16,2);
alter table public.purchase_orders add column if not exists match_status text default 'UNMATCHED';
alter table public.purchase_orders add column if not exists match_tolerance numeric(16,2) default 500.00;
alter table public.purchase_orders add column if not exists gl_journal_id uuid references public.journal_entries(id) on delete set null;
alter table public.purchase_orders add column if not exists gl_payment_journal_id uuid references public.journal_entries(id) on delete set null;

-- Extensions to existing purchase_order_items table
alter table public.purchase_order_items add column if not exists real_grn_cost numeric(14,2);
alter table public.purchase_order_items add column if not exists batch_no text;
alter table public.purchase_order_items add column if not exists expiry_date date;
alter table public.purchase_order_items add column if not exists invoice_unit_cost numeric(14,2);
alter table public.purchase_order_items add column if not exists invoice_quantity int;

-- =============================================================================
-- 4. INSURANCE / SHA CLAIMS
-- =============================================================================
create table if not exists public.insurance_claims (
  id             uuid primary key default gen_random_uuid(),
  transaction_id uuid,
  branch_id      uuid references public.branches(id) on delete set null,
  client_name    text,
  insurer        text not null,
  member_number  text,
  pre_auth_code  text,
  gross_amount   numeric(16,2) default 0,
  covered_amount numeric(16,2) default 0,
  copay_amount   numeric(16,2) default 0,
  copay_percent  numeric(6,2) default 0,
  claim_status   text default 'SUBMITTED', -- SUBMITTED | ADJUDICATED | PAID | REJECTED
  created_at     timestamptz default now()
);

-- =============================================================================
-- 5. INVENTORY BATCHES (FEFO / quarantine / real expiry)
-- =============================================================================
create table if not exists public.inventory_batches (
  id           uuid primary key default gen_random_uuid(),
  drug_id      uuid references public.drugs(id) on delete cascade,
  branch_id    uuid references public.branches(id) on delete set null,
  batch_no     text not null,
  expiry_date  date,
  quantity     int default 0,
  cost_price   numeric(14,2),
  supplier_id  uuid references public.suppliers(id) on delete set null,
  received_at  timestamptz default now(),
  grn_no       text,
  status       text default 'RELEASED',   -- RELEASED | QUARANTINED | RECALLED | EXPIRED
  quarantine_reason text,
  created_at   timestamptz default now()
);

create index if not exists idx_inventory_batches_drug on public.inventory_batches(drug_id);

-- =============================================================================
-- 6. STAFF / EMPLOYEE MASTER  (HR & Payroll)
-- =============================================================================
create table if not exists public.staff (
  id                  uuid primary key default gen_random_uuid(),
  staff_no            text unique,
  first_name          text not null,
  last_name           text not null,
  national_id         text,
  kra_pin             text,
  nssf_no             text,
  sha_no              text,
  phone               text,
  email               text,
  branch_id           uuid references public.branches(id) on delete set null,
  department          text default 'Pharmacy Operations',
  job_title           text,
  employment_type     text default 'Permanent', -- Permanent|Contract|Casual|Intern
  date_hired          date,
  date_exited         date,
  basic_salary        numeric(14,2) not null default 0,
  house_allowance     numeric(14,2) not null default 0,
  transport_allowance numeric(14,2) not null default 0,
  medical_allowance   numeric(14,2) not null default 0,
  other_allowance     numeric(14,2) not null default 0,
  pension_contribution numeric(14,2) not null default 0,
  bank_name           text,
  bank_branch         text,
  bank_account        text,
  payment_method      text default 'Bank Transfer',
  is_paye_applicable  boolean default true,
  status              text default 'Active', -- Active|Suspended|Exited
  created_at          timestamptz default now()
);

create index if not exists idx_staff_branch on public.staff(branch_id);

-- =============================================================================
-- 7. ATTENDANCE & SHIFTS
-- =============================================================================
create table if not exists public.attendance_shifts (
  id            uuid primary key default gen_random_uuid(),
  staff_id      uuid not null references public.staff(id) on delete cascade,
  branch_id     uuid references public.branches(id) on delete set null,
  shift_date    date not null,
  shift_name    text default 'Day',    -- Day|Evening|Night
  planned_start text,
  planned_end   text,
  clock_in      timestamptz,
  clock_out     timestamptz,
  hours_worked  numeric(6,2) default 0,
  overtime_hours numeric(6,2) default 0,
  status        text default 'Scheduled', -- Scheduled|Present|Absent|Leave|Off
  notes         text,
  created_at    timestamptz default now(),
  unique (staff_id, shift_date)
);

-- =============================================================================
-- 8. PAYROLL
-- =============================================================================
create table if not exists public.payroll_runs (
  id                  uuid primary key default gen_random_uuid(),
  period_start        date not null,
  period_end          date not null,
  period_label        text not null,
  branch_id           uuid references public.branches(id) on delete set null, -- null = group
  status              text default 'Draft',   -- Draft|Approved|Paid
  headcount           int default 0,
  gross_total         numeric(16,2) default 0,
  paye_total          numeric(16,2) default 0,
  nssf_employee_total numeric(16,2) default 0,
  nssf_employer_total numeric(16,2) default 0,
  shif_total          numeric(16,2) default 0,
  ahl_employee_total  numeric(16,2) default 0,
  ahl_employer_total  numeric(16,2) default 0,
  net_total           numeric(16,2) default 0,
  employer_cost_total numeric(16,2) default 0,
  approved_by         text,
  approved_at         timestamptz,
  paid_at             timestamptz,
  created_at          timestamptz default now()
);

create table if not exists public.payslips (
  id                 uuid primary key default gen_random_uuid(),
  payroll_run_id     uuid not null references public.payroll_runs(id) on delete cascade,
  staff_id           uuid references public.staff(id) on delete cascade,
  staff_no           text,
  staff_name         text,
  job_title          text,
  branch_name        text,
  gross_pay          numeric(14,2) default 0,
  allowances         numeric(14,2) default 0,
  overtime_pay       numeric(14,2) default 0,
  nssf_employee      numeric(14,2) default 0,
  nssf_employer      numeric(14,2) default 0,
  shif               numeric(14,2) default 0,
  ahl_employee       numeric(14,2) default 0,
  ahl_employer       numeric(14,2) default 0,
  pension            numeric(14,2) default 0,
  taxable_income     numeric(14,2) default 0,
  paye_before_relief numeric(14,2) default 0,
  personal_relief    numeric(14,2) default 2400,
  paye               numeric(14,2) default 0,
  other_deductions   numeric(14,2) default 0,
  total_deductions   numeric(14,2) default 0,
  net_pay            numeric(14,2) default 0,
  employer_cost      numeric(14,2) default 0,
  created_at         timestamptz default now()
);

create index if not exists idx_payslips_run on public.payslips(payroll_run_id);

-- Backward compatibility alias for payroll_items
create or replace view public.payroll_items as select * from public.payslips;

-- =============================================================================
-- 9. EXTEND TRANSACTIONS (GL traceability + insurance + cost/COGS)
-- =============================================================================
alter table public.transactions add column if not exists vat_amount        numeric(16,2) default 0;
alter table public.transactions add column if not exists cost_amount       numeric(16,2) default 0;
alter table public.transactions add column if not exists gross_profit      numeric(16,2) default 0;
alter table public.transactions add column if not exists insurer           text;
alter table public.transactions add column if not exists member_number     text;
alter table public.transactions add column if not exists pre_auth_code     text;
alter table public.transactions add column if not exists insurance_covered numeric(16,2) default 0;
alter table public.transactions add column if not exists copay_amount      numeric(16,2) default 0;
alter table public.transactions add column if not exists gl_posted         boolean default false;
alter table public.transactions add column if not exists gl_journal_id     uuid;

-- =============================================================================
-- 10. DEFAULT CHART OF ACCOUNTS (Kenya pharmacy retail + wholesale)
-- =============================================================================
insert into public.chart_of_accounts (code, name, type, category, is_control) values
 ('1000','Cash and Cash Equivalents','asset','Current Assets',true),
 ('1010','Cash in Hand - Till','asset','Current Assets',false),
 ('1020','M-Pesa Float','asset','Current Assets',true),
 ('1030','Bank - KCB Current Account','asset','Current Assets',true),
 ('1040','Bank - Equity Current Account','asset','Current Assets',true),
 ('1200','Accounts Receivable - Trade Debtors','asset','Current Assets',false),
 ('1210','Accounts Receivable - Insurance & SHA','asset','Current Assets',false),
 ('1220','Accounts Receivable - Corporate Credit','asset','Current Assets',false),
 ('1300','Inventory - Pharmaceutical Stock','asset','Current Assets',true),
 ('1350','Inventory in Transit','asset','Current Assets',true),
 ('1400','Prepayments, Deposits & Rent Deposits','asset','Current Assets',false),
 ('1500','Property, Plant & Equipment','asset','Non-Current Assets',false),
 ('1510','Accumulated Depreciation - PPE','asset','Non-Current Assets',false),
 ('1600','Motor Vehicles - Distribution Fleet','asset','Non-Current Assets',false),
 ('1700','Intangibles - Software & Licences','asset','Non-Current Assets',false),
 ('2000','Accounts Payable - Suppliers','liability','Current Liabilities',true),
 ('2100','VAT Payable - KRA Output Tax','liability','Current Liabilities',true),
 ('2110','VAT Recoverable - KRA Input Tax','asset','Current Assets',true),
 ('2200','PAYE Payable - KRA','liability','Current Liabilities',true),
 ('2210','NSSF Payable','liability','Current Liabilities',true),
 ('2220','SHIF / SHA Contributions Payable','liability','Current Liabilities',true),
 ('2230','Affordable Housing Levy Payable','liability','Current Liabilities',true),
 ('2240','NITA Payable','liability','Current Liabilities',true),
 ('2300','Accrued Salaries & Wages','liability','Current Liabilities',false),
 ('2400','Loans & Borrowings','liability','Non-Current Liabilities',false),
 ('2500','Dividends Payable','liability','Current Liabilities',false),
 ('3000','Share Capital','equity','Equity',false),
 ('3100','Retained Earnings','equity','Equity',false),
 ('3200','Current Year Earnings','equity','Equity',false),
 ('3300','Directors Drawings','equity','Equity',false),
 ('4000','Sales Revenue - Retail Pharmacy','income','Revenue',false),
 ('4010','Sales Revenue - Wholesale & Institutional','income','Revenue',false),
 ('4020','Sales Revenue - Insurance & SHA','income','Revenue',false),
 ('4030','Dispensing & Professional Service Fees','income','Revenue',false),
 ('4100','Other Income','income','Revenue',false),
 ('4200','Purchase Discounts & Rebates Received','income','Revenue',false),
 ('5000','Cost of Goods Sold','expense','Cost of Sales',true),
 ('5010','Freight & Inward Logistics','expense','Cost of Sales',false),
 ('5020','Inventory Write-off & Expiry Shrinkage','expense','Cost of Sales',false),
 ('6000','Salaries & Wages','expense','Operating Expenses',false),
 ('6010','Employer Statutory Contributions (NSSF/AHL/WIBA)','expense','Operating Expenses',false),
 ('6100','Staff Medical & Welfare','expense','Operating Expenses',false),
 ('6200','Rent & Rates','expense','Operating Expenses',false),
 ('6210','Electricity, Water & Utilities','expense','Operating Expenses',false),
 ('6300','Transport, Fuel & Fleet Running','expense','Operating Expenses',false),
 ('6310','Vehicle Maintenance & Insurance','expense','Operating Expenses',false),
 ('6400','Marketing & Merchandising','expense','Operating Expenses',false),
 ('6500','Licences & Regulatory Fees (PPB/KRA)','expense','Operating Expenses',false),
 ('6510','Professional, Audit & Legal Fees','expense','Operating Expenses',false),
 ('6600','IT, Software & Connectivity','expense','Operating Expenses',false),
 ('6700','Bank & M-Pesa Transaction Charges','expense','Operating Expenses',false),
 ('6800','Depreciation Expense','expense','Operating Expenses',false),
 ('6900','General Office & Administration','expense','Operating Expenses',false),
 ('6950','Security & Cash-in-Transit','expense','Operating Expenses',false)
on conflict (code) do nothing;

-- =============================================================================
-- 11. HELPER: seed / re-seed chart of accounts (callable from the app)
-- =============================================================================
create or replace function public.mc_seed_coa() returns int
language plpgsql security definer as $$
declare v_count int;
begin
  select count(*) into v_count from public.chart_of_accounts;
  return v_count;
end $$;

-- =============================================================================
-- 12. HELPER: atomic balanced journal posting (validates debit = credit)
-- =============================================================================
create or replace function public.mc_post_journal(
  p_date          date,
  p_memo          text,
  p_reference     text,
  p_source_module text,
  p_source_id     text,
  p_branch_id     uuid,
  p_created_by    text,
  p_lines         jsonb
) returns uuid
language plpgsql security definer as $$
declare
  v_entry_id uuid;
  v_entry_no text;
  v_debit    numeric(16,2) := 0;
  v_credit   numeric(16,2) := 0;
  v_line     jsonb;
  v_seq      int;
begin
  select coalesce(sum((l->>'debit')::numeric),0),
         coalesce(sum((l->>'credit')::numeric),0)
    into v_debit, v_credit
    from jsonb_array_elements(p_lines) l;

  if round(v_debit,2) <> round(v_credit,2) then
    raise exception 'Journal out of balance: Dr % vs Cr %', v_debit, v_credit;
  end if;
  if v_debit = 0 then
    raise exception 'Refusing to post a nil-value journal';
  end if;

  select count(*) + 1 into v_seq from public.journal_entries;
  v_entry_no := 'JE-' || to_char(coalesce(p_date, current_date),'YYYYMM') || '-' || lpad(v_seq::text, 5, '0');

  insert into public.journal_entries
    (entry_no, journal_date, reference, memo, source_module, source_id, branch_id,
     status, total_debit, total_credit, created_by, posted_at)
  values
    (v_entry_no, coalesce(p_date, current_date), p_reference, p_memo, p_source_module,
     p_source_id, p_branch_id, 'posted', v_debit, v_credit, p_created_by, now())
  returning id into v_entry_id;

  for v_line in select * from jsonb_array_elements(p_lines) loop
    insert into public.journal_lines
      (journal_id, account_code, debit, credit, branch_id, cost_center, line_memo)
    values
      (v_entry_id,
       v_line->>'account_code',
       coalesce((v_line->>'debit')::numeric,0),
       coalesce((v_line->>'credit')::numeric,0),
       case when v_line->>'branch_id' is null then p_branch_id else (v_line->>'branch_id')::uuid end,
       v_line->>'cost_center',
       v_line->>'line_memo');
  end loop;

  return v_entry_id;
end $$;

-- =============================================================================
-- 13. KRA eTIMS, TAX CLASSIFICATION, Z-REPORTS & TILL RECONCILIATION
-- =============================================================================

-- Official KRA eTIMS Tax Classification Registry (taxTyCd)
create table if not exists public.etims_tax_codes (
  code                 text primary key,
  rate                 numeric(6,4) not null default 0.1600,
  description          text not null,
  allows_input_credit  boolean default true,
  is_active            boolean default true,
  created_at           timestamptz default now()
);

-- Seed official KRA eTIMS Tax Code Mapping
insert into public.etims_tax_codes (code, rate, description, allows_input_credit) values
  ('A', 0.0000, 'Exempt (0% VAT - Input Tax Blocked under First Schedule)', false),
  ('B', 0.1600, '16% Standard VAT (Default - Input Tax Claimable)', true),
  ('C', 0.0000, 'Zero-Rated (0% VAT - Input Tax Claimable under Second Schedule)', true),
  ('D', 0.0000, 'Non-VAT / Out of Scope (0%)', false),
  ('E', 0.0800, '8% Special Reduced VAT Rate', true)
on conflict (code) do update set
  rate = excluded.rate,
  description = excluded.description,
  allows_input_credit = excluded.allows_input_credit;

-- Branch KRA Hardware / VSCU Integration Configuration (Empty by default)
create table if not exists public.branch_kra_config (
  id                  uuid primary key default gen_random_uuid(),
  branch_id           text not null unique,
  branch_name         text not null,
  kra_pin             text not null,
  etims_device_id     text not null,
  machine_number      text not null,
  branch_identifier   text,
  is_active           boolean default true,
  registered_at       timestamptz default now()
);

create table if not exists public.etims_invoices (
  id                    uuid primary key default gen_random_uuid(),
  invoice_number        text not null unique,
  cu_invoice_number     text not null,
  cu_serial_number      text not null,
  kra_pin               text not null,
  trader_name           text not null default 'Mediocare Pharmacy Ltd',
  branch_name           text not null,
  branch_id             text,
  customer_name         text default 'Walk-in Customer',
  customer_pin          text,
  date_time             timestamptz not null default now(),
  items                 jsonb not null default '[]'::jsonb,
  payment_mode          text default 'M-Pesa',
  payment_reference     text,
  cashier_name          text,
  total_taxable_a       numeric(16,2) default 0,
  total_taxable_b       numeric(16,2) default 0,
  total_tax_b           numeric(16,2) default 0,
  total_taxable_c       numeric(16,2) default 0,
  total_taxable_d       numeric(16,2) default 0,
  total_taxable_e       numeric(16,2) default 0,
  total_tax_e           numeric(16,2) default 0,
  total_net             numeric(16,2) default 0,
  total_tax             numeric(16,2) default 0,
  total_gross           numeric(16,2) default 0,
  local_integrity_hash  text not null,
  cu_signature          text,
  verification_url      text not null,
  created_at            timestamptz default now()
);

create table if not exists public.etims_z_reports (
  id                   uuid primary key default gen_random_uuid(),
  z_report_number      text not null unique,
  date                 date not null default current_date,
  branch_name          text not null,
  branch_id            text,
  cu_serial_number     text not null,
  start_invoice_number text,
  end_invoice_number   text,
  total_invoices       int default 0,
  gross_sales          numeric(16,2) default 0,
  net_sales            numeric(16,2) default 0,
  tax_code_a_sales     numeric(16,2) default 0,
  tax_code_b_sales     numeric(16,2) default 0,
  tax_code_b_tax       numeric(16,2) default 0,
  tax_code_c_sales     numeric(16,2) default 0,
  tax_code_d_sales     numeric(16,2) default 0,
  tax_code_e_sales     numeric(16,2) default 0,
  tax_code_e_tax       numeric(16,2) default 0,
  total_tax            numeric(16,2) default 0,
  payment_breakdown    jsonb default '{}'::jsonb,
  generated_at         timestamptz default now(),
  supervisor_sign_off  text,
  created_at           timestamptz default now()
);

create table if not exists public.branch_till_sessions (
  id                    uuid primary key default gen_random_uuid(),
  session_id            text not null unique,
  branch_name           text not null,
  branch_id             text,
  cashier_name          text not null,
  shift_start           timestamptz not null default now(),
  shift_end             timestamptz,
  opening_float         numeric(16,2) default 0,
  cash_sales            numeric(16,2) default 0,
  mpesa_sales           numeric(16,2) default 0,
  card_sales            numeric(16,2) default 0,
  insurance_sales       numeric(16,2) default 0,
  petty_cash_payouts    numeric(16,2) default 0,
  actual_cash_in_drawer numeric(16,2) default 0,
  expected_cash_in_drawer numeric(16,2) default 0,
  variance              numeric(16,2) default 0,
  total_revenue         numeric(16,2) default 0,
  status                text default 'OPEN',
  manager_notes         text,
  created_at            timestamptz default now()
);

create table if not exists public.internal_requisitions (
  id                    uuid primary key default gen_random_uuid(),
  requisition_no        text not null unique,
  source_branch_id      uuid references public.branches(id) on delete set null,
  destination_branch_id uuid references public.branches(id) on delete set null,
  requested_by          text default 'Branch Manager',
  status                text default 'DRAFT' check (status in ('DRAFT','SUBMITTED','APPROVED','PICKING','PICKED','DISPATCHED','IN_TRANSIT','DELIVERED','RECEIVED','CLOSED','REJECTED')),
  notes                 text,
  total_items_count     int default 0,
  rider_id              text,
  rider_name            text,
  vehicle_id            text,
  vehicle_plate         text,
  approved_by           text,
  approved_at           timestamptz,
  picked_by             text,
  picked_at             timestamptz,
  dispatched_by         text,
  dispatched_at         timestamptz,
  delivered_by          text,
  delivered_at          timestamptz,
  received_by           text,
  received_at           timestamptz,
  gl_journal_id         uuid references public.journal_entries(id) on delete set null,
  created_at            timestamptz default now(),
  updated_at            timestamptz default now()
);

-- Ensure all columns exist even if internal_requisitions pre-existed
alter table public.internal_requisitions add column if not exists requisition_no text;
alter table public.internal_requisitions add column if not exists requesting_branch_id uuid references public.branches(id) on delete set null;
alter table public.internal_requisitions add column if not exists supplying_branch_id uuid references public.branches(id) on delete set null;
alter table public.internal_requisitions add column if not exists source_branch_id uuid references public.branches(id) on delete set null;
alter table public.internal_requisitions add column if not exists destination_branch_id uuid references public.branches(id) on delete set null;
alter table public.internal_requisitions add column if not exists requested_by text;
alter table public.internal_requisitions add column if not exists notes text;
alter table public.internal_requisitions add column if not exists total_items_count int default 0;
alter table public.internal_requisitions add column if not exists rider_id text;
alter table public.internal_requisitions add column if not exists rider_name text;
alter table public.internal_requisitions add column if not exists vehicle_id text;
alter table public.internal_requisitions add column if not exists vehicle_plate text;
alter table public.internal_requisitions add column if not exists approved_by text;
alter table public.internal_requisitions add column if not exists approved_at timestamptz;
alter table public.internal_requisitions add column if not exists rejection_reason text;
alter table public.internal_requisitions add column if not exists picked_by text;
alter table public.internal_requisitions add column if not exists picked_at timestamptz;
alter table public.internal_requisitions add column if not exists dispatched_by text;
alter table public.internal_requisitions add column if not exists dispatched_at timestamptz;
alter table public.internal_requisitions add column if not exists delivered_by text;
alter table public.internal_requisitions add column if not exists delivered_at timestamptz;
alter table public.internal_requisitions add column if not exists received_by text;
alter table public.internal_requisitions add column if not exists received_at timestamptz;
alter table public.internal_requisitions add column if not exists gl_journal_id uuid references public.journal_entries(id) on delete set null;
alter table public.internal_requisitions add column if not exists updated_at timestamptz default now();

create table if not exists public.requisition_items (
  id                   uuid primary key default gen_random_uuid(),
  requisition_id       uuid not null references public.internal_requisitions(id) on delete cascade,
  drug_id              uuid references public.drugs(id) on delete cascade,
  drug_name            text not null,
  quantity_requested   int not null default 1,
  quantity_picked      int default 0,
  quantity_received    int default 0,
  unit_cost            numeric(14,2) default 0.0,
  batch_no             text,
  expiry_date          date,
  bin_location         text,
  created_at           timestamptz default now()
);

-- Ensure all columns exist even if requisition_items pre-existed
alter table public.requisition_items add column if not exists quantity_requested int default 1;
alter table public.requisition_items add column if not exists approved_qty int default 0;
alter table public.requisition_items add column if not exists picked_qty int default 0;
alter table public.requisition_items add column if not exists quantity_picked int default 0;
alter table public.requisition_items add column if not exists quantity_received int default 0;
alter table public.requisition_items add column if not exists unit_cost numeric(14,2) default 0.0;
alter table public.requisition_items add column if not exists batch_id uuid;
alter table public.requisition_items add column if not exists batch_no text;
alter table public.requisition_items add column if not exists expiry_date date;
alter table public.requisition_items add column if not exists bin_location text;
alter table public.requisition_items add column if not exists created_at timestamptz default now();

create table if not exists public.requisition_audit_logs (
  id             uuid primary key default gen_random_uuid(),
  requisition_id uuid not null references public.internal_requisitions(id) on delete cascade,
  from_status    text,
  to_status      text not null,
  action         text not null,
  actor          text not null,
  notes          text,
  created_at     timestamptz default now()
);

create table if not exists public.leave_types (
  id             uuid primary key default gen_random_uuid(),
  code           text not null unique,
  name           text not null,
  default_days   int not null default 0,
  is_statutory   boolean not null default true,
  pay_percentage numeric(5,2) not null default 100.00,
  description    text,
  created_at     timestamptz default now(),
  updated_at     timestamptz default now()
);

insert into public.leave_types (code, name, default_days, is_statutory, pay_percentage, description) values
  ('ANNUAL', 'Annual Leave', 21, true, 100.00, 'Statutory minimum under Employment Act 2007 (21 working days with full pay)'),
  ('SICK_FULL', 'Sick Leave (Full Pay)', 7, true, 100.00, 'Statutory sick leave under Employment Act 2007 Section 30 (7 consecutive days on full pay)'),
  ('SICK_HALF', 'Sick Leave (Half Pay)', 7, true, 50.00, 'Statutory sick leave under Employment Act 2007 Section 30 (7 consecutive days on half pay)'),
  ('SICK_POLICY', 'Extended Sick Leave (Company Policy)', 16, false, 100.00, 'Configurable group benefit policy extending paid sick days beyond statutory minimum'),
  ('MATERNITY', 'Maternity Leave', 90, true, 100.00, 'Statutory maternity entitlement under Employment Act 2007 (3 calendar months fully paid)'),
  ('PATERNITY', 'Paternity Leave', 14, true, 100.00, 'Statutory paternity entitlement under Employment Act 2007 (2 weeks fully paid)'),
  ('COMPASSIONATE', 'Compassionate Leave', 5, false, 100.00, 'Configurable company policy for bereavement and immediate family emergencies'),
  ('UNPAID', 'Unpaid Leave', 0, false, 0.00, 'Authorized unpaid leave that automatically feeds daily rate payroll deductions')
on conflict (code) do nothing;

create table if not exists public.leave_requests (
  id             uuid primary key default gen_random_uuid(),
  staff_id       uuid references public.staff(id) on delete set null,
  staff_name     text not null,
  staff_no       text,
  department     text,
  leave_type     text not null,
  start_date     date not null,
  end_date       date not null,
  total_days     int not null default 1,
  reason         text,
  status         text default 'Pending' check (status in ('Pending','Approved','Rejected')),
  manager_comment text,
  reviewed_by    text,
  reviewed_at    timestamptz,
  created_at     timestamptz default now()
);

-- Ensure all columns exist even if leave_requests pre-existed
alter table public.leave_requests add column if not exists staff_id uuid references public.staff(id) on delete set null;
alter table public.leave_requests add column if not exists staff_name text;
alter table public.leave_requests add column if not exists staff_no text;
alter table public.leave_requests add column if not exists department text;
alter table public.leave_requests add column if not exists leave_type text default 'ANNUAL';
alter table public.leave_requests add column if not exists total_days int default 1;
alter table public.leave_requests add column if not exists manager_comment text;
alter table public.leave_requests add column if not exists reviewed_by text;
alter table public.leave_requests add column if not exists reviewed_at timestamptz;

create table if not exists public.leave_balances (
  id             uuid primary key default gen_random_uuid(),
  staff_id       uuid not null references public.staff(id) on delete cascade,
  year           int not null default extract(year from current_date),
  annual_entitlement int default 21,
  annual_used    int default 0,
  sick_entitlement   int default 30,
  sick_used      int default 0,
  unpaid_used    int default 0,
  created_at     timestamptz default now(),
  unique(staff_id, year)
);

create table if not exists public.fleet_vehicles (
  id                uuid primary key default gen_random_uuid(),
  plate_number      text not null unique,
  vehicle_model     text not null,
  driver_name       text,
  driver_phone      text,
  current_lat       numeric(10,6),
  current_lng       numeric(10,6),
  speed_kmh         numeric(6,2),
  temp_celsius      numeric(5,2),
  last_telemetry_at timestamptz,
  status            text default 'Active',
  created_at        timestamptz default now()
);

-- =============================================================================
-- 14. ROW LEVEL SECURITY + GRANTS (so the anon client key can read/write)
-- =============================================================================
do $$
declare
  t text;
  tables text[] := array[
    'chart_of_accounts','journal_entries','journal_lines','suppliers',
    'insurance_claims','inventory_batches','staff','attendance_shifts',
    'payroll_runs','payslips','etims_tax_codes','branch_kra_config',
    'etims_invoices','etims_z_reports','branch_till_sessions',
    'purchase_orders','purchase_order_items','inventory',
    'internal_requisitions','requisition_items','requisition_audit_logs',
    'leave_types','leave_requests','leave_balances','fleet_vehicles'
  ];
begin
  foreach t in array tables loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists mediocare_anon_full on public.%I', t);
    execute format('create policy mediocare_anon_full on public.%I for all to anon, authenticated using (true) with check (true)', t);
    execute format('grant all on table public.%I to anon, authenticated', t);
  end loop;
end $$;

grant usage on schema public to anon, authenticated;
grant execute on function public.mc_seed_coa() to anon, authenticated;
grant execute on function public.mc_post_journal(date,text,text,text,text,uuid,text,jsonb) to anon, authenticated;

-- =============================================================================
-- 15. PERFORMANCE INDEXES & EGRESS OPTIMIZATION (SUPABASE FREE TIER)
-- =============================================================================
alter table public.drugs add column if not exists thumb_url text;

create index if not exists idx_transactions_branch_date on public.transactions(branch_id, transaction_date desc);
create index if not exists idx_transactions_type_date on public.transactions(transaction_type, transaction_date desc);
create index if not exists idx_transactions_drug_id on public.transactions(drug_id);
create index if not exists idx_drugs_name on public.drugs(name);
create index if not exists idx_drugs_category on public.drugs(category);
create index if not exists idx_inventory_batches_expiry on public.inventory_batches(expiry_date);
create index if not exists idx_journal_lines_account on public.journal_lines(account_code);
create index if not exists idx_journal_entries_date on public.journal_entries(journal_date desc);
create index if not exists idx_transactions_unposted_gl on public.transactions(gl_posted) where gl_posted = false;

-- =============================================================================
-- 16. HIGH SPEED RPC: mc_branch_revenue (Single round trip aggregated revenue)
-- =============================================================================
create or replace function public.mc_branch_revenue()
returns table(branch_id uuid, branch_name text, code text, revenue numeric)
language plpgsql security definer as $$
begin
  return query
  select 
    b.id as branch_id,
    b.name::text as branch_name,
    b.code::text as code,
    coalesce(sum(t.total_amount), 0.00)::numeric(16,2) as revenue
  from public.branches b
  left join public.transactions t 
    on t.branch_id = b.id and t.transaction_type = 'sale'
  group by b.id, b.name, b.code
  order by b.name;
end;
$$;

-- =============================================================================
-- 17. HIGH SPEED RPC: mc_dashboard_kpis (CEO / Branch Header KPIs in 1 call)
-- =============================================================================
create or replace function public.mc_dashboard_kpis(p_branch_id uuid default null)
returns json language plpgsql security definer as $$
declare
  v_rev numeric;
  v_today_rev numeric;
  v_tx_count int;
  v_low_stock int;
  v_pending_pos int;
  v_unposted_gl int;
begin
  -- Total Sales Revenue
  select coalesce(sum(total_amount), 0.00), count(*)
  into v_rev, v_tx_count
  from public.transactions
  where transaction_type = 'sale'
    and (p_branch_id is null or branch_id = p_branch_id);

  -- Today's Sales Revenue
  select coalesce(sum(total_amount), 0.00)
  into v_today_rev
  from public.transactions
  where transaction_type = 'sale'
    and transaction_date >= current_date
    and (p_branch_id is null or branch_id = p_branch_id);

  -- Low Stock Items Count
  select count(*)
  into v_low_stock
  from public.drugs
  where quantity_in_stock <= coalesce(reorder_level, min_threshold, 15);

  -- Pending Purchase Orders
  select count(*)
  into v_pending_pos
  from public.purchase_orders
  where status in ('draft', 'submitted', 'approved')
    and (p_branch_id is null or branch_id = p_branch_id);

  -- Unposted GL Transactions
  select count(*)
  into v_unposted_gl
  from public.transactions
  where gl_posted = false
    and (p_branch_id is null or branch_id = p_branch_id);

  return json_build_object(
    'total_revenue', v_rev,
    'today_revenue', v_today_rev,
    'total_transactions', v_tx_count,
    'low_stock_count', v_low_stock,
    'pending_pos', v_pending_pos,
    'unposted_gl_count', v_unposted_gl
  );
end;
$$;

grant execute on function public.mc_branch_revenue() to anon, authenticated;
grant execute on function public.mc_dashboard_kpis(uuid) to anon, authenticated;


-- Additive Schema & RLS for Secretary Branch Scoping

-- 1. Additive columns
ALTER TABLE branches ADD COLUMN IF NOT EXISTS monthly_expense_budget numeric;
ALTER TABLE imprest_ledger ADD COLUMN IF NOT EXISTS branch_id uuid REFERENCES branches(id);
ALTER TABLE mpesa_transactions ADD COLUMN IF NOT EXISTS branch_id uuid REFERENCES branches(id);

-- 2. Backfill imprest_ledger branch_id if text branch exists
UPDATE imprest_ledger il
SET branch_id = b.id
FROM branches b
WHERE lower(il.branch) = lower(b.name) AND il.branch_id IS NULL;

-- 3. Security Helper Functions
CREATE OR REPLACE FUNCTION public.get_auth_user_branch_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS 
  SELECT s.branch_id 
  FROM public.staff s 
  WHERE s.email = (auth.jwt() ->> 'email') OR s.user_id = auth.uid() 
  LIMIT 1;
;

CREATE OR REPLACE FUNCTION public.is_admin_or_ceo()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS 
  SELECT EXISTS (
    SELECT 1 FROM public.roles 
    WHERE email = (auth.jwt() ->> 'email') 
      AND UPPER(role) IN ('SUPER_ADMIN', 'SUPERADMIN', 'CEO', 'ADMIN')
  ) OR (auth.jwt() ->> 'email') IN ('admin@pharmacy.com', 'ceo@pharmacy.com');
;

-- Allow authenticated users to query staff
DROP POLICY IF EXISTS staff_read_authenticated ON staff;
CREATE POLICY staff_read_authenticated ON staff
FOR SELECT TO authenticated
USING (true);

-- 4. Secretary Branch Isolation Policies across all 8 Tables

-- Table 1: eod_declarations
ALTER TABLE eod_declarations ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS eod_declarations_branch_isolation ON eod_declarations;
DROP POLICY IF EXISTS Allow all eod_declarations ON eod_declarations;
DROP POLICY IF EXISTS Enable all for eod_declarations ON eod_declarations;
CREATE POLICY eod_declarations_branch_isolation ON eod_declarations
FOR ALL TO authenticated
USING (public.is_admin_or_ceo() OR branch_id = public.get_auth_user_branch_id())
WITH CHECK (public.is_admin_or_ceo() OR branch_id = public.get_auth_user_branch_id());

-- Table 2: branch_bank_deposits
ALTER TABLE branch_bank_deposits ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS branch_bank_deposits_branch_isolation ON branch_bank_deposits;
DROP POLICY IF EXISTS Allow all branch_bank_deposits ON branch_bank_deposits;
CREATE POLICY branch_bank_deposits_branch_isolation ON branch_bank_deposits
FOR ALL TO authenticated
USING (public.is_admin_or_ceo() OR branch_id = public.get_auth_user_branch_id())
WITH CHECK (public.is_admin_or_ceo() OR branch_id = public.get_auth_user_branch_id());

-- Table 3: insurance_claims
ALTER TABLE insurance_claims ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS insurance_claims_branch_isolation ON insurance_claims;
DROP POLICY IF EXISTS mediocare_anon_full ON insurance_claims;
CREATE POLICY insurance_claims_branch_isolation ON insurance_claims
FOR ALL TO authenticated
USING (public.is_admin_or_ceo() OR branch_id = public.get_auth_user_branch_id())
WITH CHECK (public.is_admin_or_ceo() OR branch_id = public.get_auth_user_branch_id());

-- Table 4: branch_supplier_invoices
ALTER TABLE branch_supplier_invoices ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS branch_supplier_invoices_branch_isolation ON branch_supplier_invoices;
DROP POLICY IF EXISTS Allow all branch_supplier_invoices ON branch_supplier_invoices;
CREATE POLICY branch_supplier_invoices_branch_isolation ON branch_supplier_invoices
FOR ALL TO authenticated
USING (public.is_admin_or_ceo() OR branch_id = public.get_auth_user_branch_id())
WITH CHECK (public.is_admin_or_ceo() OR branch_id = public.get_auth_user_branch_id());

-- Table 5: imprest_ledger
ALTER TABLE imprest_ledger ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS imprest_ledger_branch_isolation ON imprest_ledger;
DROP POLICY IF EXISTS Enable all for imprest_ledger ON imprest_ledger;
CREATE POLICY imprest_ledger_branch_isolation ON imprest_ledger
FOR ALL TO authenticated
USING (public.is_admin_or_ceo() OR branch_id = public.get_auth_user_branch_id())
WITH CHECK (public.is_admin_or_ceo() OR branch_id = public.get_auth_user_branch_id());

-- Table 6: branch_shift_handovers
ALTER TABLE branch_shift_handovers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS branch_shift_handovers_branch_isolation ON branch_shift_handovers;
DROP POLICY IF EXISTS Allow all branch_shift_handovers ON branch_shift_handovers;
CREATE POLICY branch_shift_handovers_branch_isolation ON branch_shift_handovers
FOR ALL TO authenticated
USING (public.is_admin_or_ceo() OR branch_id = public.get_auth_user_branch_id())
WITH CHECK (public.is_admin_or_ceo() OR branch_id = public.get_auth_user_branch_id());

-- Table 7: etims_invoices
ALTER TABLE etims_invoices ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS etims_invoices_branch_isolation ON etims_invoices;
DROP POLICY IF EXISTS mediocare_anon_full ON etims_invoices;
CREATE POLICY etims_invoices_branch_isolation ON etims_invoices
FOR ALL TO authenticated
USING (
  public.is_admin_or_ceo() 
  OR branch_id = (public.get_auth_user_branch_id())::text 
  OR (CASE WHEN branch_id ~ '^[0-9a-fA-F-]{36}$' THEN branch_id::uuid = public.get_auth_user_branch_id() ELSE false END)
)
WITH CHECK (
  public.is_admin_or_ceo() 
  OR branch_id = (public.get_auth_user_branch_id())::text 
  OR (CASE WHEN branch_id ~ '^[0-9a-fA-F-]{36}$' THEN branch_id::uuid = public.get_auth_user_branch_id() ELSE false END)
);

-- Table 8: mpesa_transactions
ALTER TABLE mpesa_transactions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS mpesa_transactions_branch_isolation ON mpesa_transactions;
CREATE POLICY mpesa_transactions_branch_isolation ON mpesa_transactions
FOR ALL TO authenticated
USING (public.is_admin_or_ceo() OR branch_id = public.get_auth_user_branch_id())
WITH CHECK (public.is_admin_or_ceo() OR branch_id = public.get_auth_user_branch_id());

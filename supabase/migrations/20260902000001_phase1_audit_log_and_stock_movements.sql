-- =============================================================================
-- Migration: 20260902000001_phase1_audit_log_and_stock_movements.sql
-- Description: Phase 1 Trust Layer - Immutable Hash-Chained Audit Log & Stock Movements
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- -----------------------------------------------------------------------------
-- 1. IMMUTABLE AUDIT LOG TABLE
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.audit_log (
  id bigserial PRIMARY KEY,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  actor_user_id uuid,
  actor_role text,
  branch_id uuid,
  table_name text NOT NULL,
  record_id text NOT NULL,
  action text NOT NULL,              -- INSERT | UPDATE | DELETE
  diff jsonb,                        -- changed fields ONLY, not full snapshots
  prev_hash text NOT NULL,
  row_hash text NOT NULL
);

-- Revoke mutation rights from application roles
REVOKE UPDATE, DELETE, TRUNCATE ON public.audit_log FROM anon, authenticated;

-- Function to compute canonical JSON row hash with advisory transaction lock
CREATE OR REPLACE FUNCTION public.audit_log_hash_chain()
RETURNS TRIGGER AS $$
DECLARE
  last_hash text;
  payload text;
BEGIN
  -- Advisory transaction lock prevents concurrent forks and serializes hash assignment
  PERFORM pg_advisory_xact_lock(7101001);

  -- Get the hash of the immediately preceding record (or 64 zeros for genesis row)
  SELECT row_hash INTO last_hash
  FROM public.audit_log
  ORDER BY id DESC
  LIMIT 1;

  IF last_hash IS NULL THEN
    last_hash := repeat('0', 64);
  END IF;

  NEW.prev_hash := last_hash;
  
  -- Compute canonical hash: sha256(prev_hash | table_name | record_id | action | diff)
  payload := NEW.prev_hash || '|' || 
             NEW.table_name || '|' || 
             NEW.record_id || '|' || 
             NEW.action || '|' || 
             COALESCE(NEW.diff::text, '{}');

  NEW.row_hash := encode(digest(payload, 'sha256'), 'hex');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_audit_log_hash ON public.audit_log;
CREATE TRIGGER trg_audit_log_hash
BEFORE INSERT ON public.audit_log
FOR EACH ROW
EXECUTE FUNCTION public.audit_log_hash_chain();

-- Function to verify audit chain integrity
CREATE OR REPLACE FUNCTION public.verify_audit_chain()
RETURNS bigint AS $$
DECLARE
  rec RECORD;
  expected_prev text := repeat('0', 64);
  computed_hash text;
  payload text;
BEGIN
  FOR rec IN SELECT * FROM public.audit_log ORDER BY id ASC LOOP
    IF rec.prev_hash != expected_prev THEN
      RETURN rec.id; -- Chain broken at this ID (prev_hash mismatch)
    END IF;

    payload := rec.prev_hash || '|' || 
               rec.table_name || '|' || 
               rec.record_id || '|' || 
               rec.action || '|' || 
               COALESCE(rec.diff::text, '{}');

    computed_hash := encode(digest(payload, 'sha256'), 'hex');
    IF rec.row_hash != computed_hash THEN
      RETURN rec.id; -- Chain broken at this ID (row_hash tampering)
    END IF;

    expected_prev := rec.row_hash;
  END LOOP;

  RETURN NULL; -- Chain 100% valid and unbroken
END;
$$ LANGUAGE plpgsql STABLE;

-- -----------------------------------------------------------------------------
-- 2. GENERIC CAPTURE TRIGGER FUNCTION (CHANGED FIELDS ONLY IN DIFF)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.process_audit_capture()
RETURNS TRIGGER AS $$
DECLARE
  v_action text;
  v_record_id text;
  v_diff jsonb := '{}'::jsonb;
  v_actor_user_id uuid;
  v_actor_role text;
  v_branch_id uuid;
  k text;
  v_old_val jsonb;
  v_new_val jsonb;
  v_old_json jsonb;
  v_new_json jsonb;
BEGIN
  IF TG_OP = 'INSERT' THEN
    v_action := 'INSERT';
    v_record_id := NEW.id::text;
    v_diff := to_jsonb(NEW);
    IF to_jsonb(NEW) ? 'branch_id' THEN
      v_branch_id := (to_jsonb(NEW) ->> 'branch_id')::uuid;
    END IF;
  ELSIF TG_OP = 'UPDATE' THEN
    v_action := 'UPDATE';
    v_record_id := NEW.id::text;
    v_old_json := to_jsonb(OLD);
    v_new_json := to_jsonb(NEW);
    
    -- Changed fields ONLY: compare each key
    FOR k IN SELECT jsonb_object_keys(v_new_json) LOOP
      v_old_val := v_old_json -> k;
      v_new_val := v_new_json -> k;
      IF v_old_val IS DISTINCT FROM v_new_val THEN
        v_diff := v_diff || jsonb_build_object(k, jsonb_build_object('old', v_old_val, 'new', v_new_val));
      END IF;
    END LOOP;

    -- If no fields actually changed, skip writing duplicate log
    IF v_diff = '{}'::jsonb THEN
      RETURN NEW;
    END IF;

    IF v_new_json ? 'branch_id' THEN
      v_branch_id := (v_new_json ->> 'branch_id')::uuid;
    END IF;
  ELSIF TG_OP = 'DELETE' THEN
    v_action := 'DELETE';
    v_record_id := OLD.id::text;
    v_diff := to_jsonb(OLD);
    IF to_jsonb(OLD) ? 'branch_id' THEN
      v_branch_id := (to_jsonb(OLD) ->> 'branch_id')::uuid;
    END IF;
  END IF;

  -- Extract authenticated user context if present
  BEGIN
    v_actor_user_id := auth.uid();
    v_actor_role := (auth.jwt() ->> 'role');
  EXCEPTION WHEN OTHERS THEN
    v_actor_user_id := NULL;
    v_actor_role := NULL;
  END;

  INSERT INTO public.audit_log (
    actor_user_id,
    actor_role,
    branch_id,
    table_name,
    record_id,
    action,
    diff
  ) VALUES (
    v_actor_user_id,
    v_actor_role,
    v_branch_id,
    TG_TABLE_NAME,
    v_record_id,
    v_action,
    v_diff
  );

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Per-table capture triggers on the 8 required tables
DROP TRIGGER IF EXISTS trg_audit_drugs ON public.drugs;
CREATE TRIGGER trg_audit_drugs AFTER INSERT OR UPDATE OR DELETE ON public.drugs
FOR EACH ROW EXECUTE FUNCTION public.process_audit_capture();

DROP TRIGGER IF EXISTS trg_audit_branches ON public.branches;
CREATE TRIGGER trg_audit_branches AFTER INSERT OR UPDATE OR DELETE ON public.branches
FOR EACH ROW EXECUTE FUNCTION public.process_audit_capture();

DROP TRIGGER IF EXISTS trg_audit_staff ON public.staff;
CREATE TRIGGER trg_audit_staff AFTER INSERT OR UPDATE OR DELETE ON public.staff
FOR EACH ROW EXECUTE FUNCTION public.process_audit_capture();

DROP TRIGGER IF EXISTS trg_audit_transactions ON public.transactions;
CREATE TRIGGER trg_audit_transactions AFTER INSERT OR UPDATE OR DELETE ON public.transactions
FOR EACH ROW EXECUTE FUNCTION public.process_audit_capture();

DROP TRIGGER IF EXISTS trg_audit_inventory_batches ON public.inventory_batches;
CREATE TRIGGER trg_audit_inventory_batches AFTER INSERT OR UPDATE OR DELETE ON public.inventory_batches
FOR EACH ROW EXECUTE FUNCTION public.process_audit_capture();

DROP TRIGGER IF EXISTS trg_audit_internal_requisitions ON public.internal_requisitions;
CREATE TRIGGER trg_audit_internal_requisitions AFTER INSERT OR UPDATE OR DELETE ON public.internal_requisitions
FOR EACH ROW EXECUTE FUNCTION public.process_audit_capture();

DROP TRIGGER IF EXISTS trg_audit_deliveries ON public.deliveries;
CREATE TRIGGER trg_audit_deliveries AFTER INSERT OR UPDATE OR DELETE ON public.deliveries
FOR EACH ROW EXECUTE FUNCTION public.process_audit_capture();

DROP TRIGGER IF EXISTS trg_audit_journal_entries ON public.journal_entries;
CREATE TRIGGER trg_audit_journal_entries AFTER INSERT OR UPDATE OR DELETE ON public.journal_entries
FOR EACH ROW EXECUTE FUNCTION public.process_audit_capture();

-- -----------------------------------------------------------------------------
-- 3. IMMUTABLE STOCK MOVEMENTS LEDGER
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.stock_movements (
  id bigserial PRIMARY KEY,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  drug_id uuid NOT NULL,
  batch_id uuid,
  qty_change numeric NOT NULL,        -- signed
  from_location text NOT NULL,        -- branch | GIT | DAMAGED | VARIANCE | SUPPLIER | CUSTOMER
  to_location   text NOT NULL,
  document_type text NOT NULL,        -- GRN | TRANSFER | SALE | ADJUSTMENT | COUNT
  document_id uuid,
  actor_user_id uuid,
  branch_id uuid,
  prev_hash text NOT NULL,
  row_hash text NOT NULL
);

-- Revoke mutation rights from application roles
REVOKE UPDATE, DELETE, TRUNCATE ON public.stock_movements FROM anon, authenticated;

-- Function to compute canonical stock movement hash with advisory transaction lock
CREATE OR REPLACE FUNCTION public.stock_movements_hash_chain()
RETURNS TRIGGER AS $$
DECLARE
  last_hash text;
  payload text;
BEGIN
  -- Advisory transaction lock prevents concurrent forks and serializes hash assignment
  PERFORM pg_advisory_xact_lock(7101002);

  SELECT row_hash INTO last_hash
  FROM public.stock_movements
  ORDER BY id DESC
  LIMIT 1;

  IF last_hash IS NULL THEN
    last_hash := repeat('0', 64);
  END IF;

  NEW.prev_hash := last_hash;

  payload := NEW.prev_hash || '|' || 
             NEW.drug_id::text || '|' || 
             NEW.qty_change::text || '|' || 
             NEW.from_location || '|' || 
             NEW.to_location || '|' || 
             NEW.document_type || '|' || 
             COALESCE(NEW.document_id::text, '');

  NEW.row_hash := encode(digest(payload, 'sha256'), 'hex');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_stock_movements_hash ON public.stock_movements;
CREATE TRIGGER trg_stock_movements_hash
BEFORE INSERT ON public.stock_movements
FOR EACH ROW
EXECUTE FUNCTION public.stock_movements_hash_chain();

-- Function to verify stock movements chain integrity
CREATE OR REPLACE FUNCTION public.verify_stock_movements_chain()
RETURNS bigint AS $$
DECLARE
  rec RECORD;
  expected_prev text := repeat('0', 64);
  computed_hash text;
  payload text;
BEGIN
  FOR rec IN SELECT * FROM public.stock_movements ORDER BY id ASC LOOP
    IF rec.prev_hash != expected_prev THEN
      RETURN rec.id;
    END IF;

    payload := rec.prev_hash || '|' || 
               rec.drug_id::text || '|' || 
               rec.qty_change::text || '|' || 
               rec.from_location || '|' || 
               rec.to_location || '|' || 
               rec.document_type || '|' || 
               COALESCE(rec.document_id::text, '');

    computed_hash := encode(digest(payload, 'sha256'), 'hex');
    IF rec.row_hash != computed_hash THEN
      RETURN rec.id;
    END IF;

    expected_prev := rec.row_hash;
  END LOOP;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql STABLE;

-- -----------------------------------------------------------------------------
-- 4. ROW-LEVEL SECURITY POLICIES (BRANCH-SCOPED)
-- -----------------------------------------------------------------------------
ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stock_movements ENABLE ROW LEVEL SECURITY;

CREATE POLICY audit_log_read_scoped ON public.audit_log
FOR SELECT TO authenticated
USING (
  (auth.jwt() ->> 'email') IN ('admin@pharmacy.com', 'ceo@pharmacy.com')
  OR branch_id IN (
    SELECT branch_id FROM public.staff WHERE email = (auth.jwt() ->> 'email')
  )
);

CREATE POLICY stock_movements_read_scoped ON public.stock_movements
FOR SELECT TO authenticated
USING (
  (auth.jwt() ->> 'email') IN ('admin@pharmacy.com', 'ceo@pharmacy.com')
  OR branch_id IN (
    SELECT branch_id FROM public.staff WHERE email = (auth.jwt() ->> 'email')
  )
);

CREATE POLICY stock_movements_insert_authenticated ON public.stock_movements
FOR INSERT TO authenticated
WITH CHECK (
  (auth.jwt() ->> 'email') IN ('admin@pharmacy.com', 'ceo@pharmacy.com')
  OR branch_id IN (
    SELECT branch_id FROM public.staff WHERE email = (auth.jwt() ->> 'email')
  )
);

-- ============================================================================
-- Enterprise Pharmacy Management System (ERP) - Supabase PostgreSQL Schema
-- ============================================================================

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 2. TABLES CREATION

-- BRANCHES
CREATE TABLE IF NOT EXISTS public.branches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    code TEXT UNIQUE NOT NULL,
    location TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- USERS (Extends auth or application users)
CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT UNIQUE NOT NULL,
    full_name TEXT NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('CEO', 'Manager', 'Pharmacist', 'Storekeeper')) DEFAULT 'Pharmacist',
    branch_id UUID REFERENCES public.branches(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- DRUGS CATALOG
CREATE TABLE IF NOT EXISTS public.drugs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sku TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    generic_name TEXT,
    category TEXT NOT NULL,
    unit TEXT NOT NULL DEFAULT 'Box',
    bin_location TEXT NOT NULL DEFAULT 'AISLE 1 - SHELF A1',
    unit_price NUMERIC(10,2) NOT NULL DEFAULT 0.00,
    cost_price NUMERIC(10,2) NOT NULL DEFAULT 0.00,
    min_threshold INT NOT NULL DEFAULT 15,
    max_threshold INT NOT NULL DEFAULT 150,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- INVENTORY PER BRANCH
CREATE TABLE IF NOT EXISTS public.inventory (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    branch_id UUID NOT NULL REFERENCES public.branches(id) ON DELETE CASCADE,
    drug_id UUID NOT NULL REFERENCES public.drugs(id) ON DELETE CASCADE,
    quantity INT NOT NULL DEFAULT 0,
    batch_number TEXT NOT NULL,
    expiry_date DATE NOT NULL,
    last_updated TIMESTAMPTZ DEFAULT now(),
    CONSTRAINT unique_branch_drug_batch UNIQUE (branch_id, drug_id, batch_number)
);

-- PURCHASE ORDERS
CREATE TABLE IF NOT EXISTS public.purchase_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    po_number TEXT UNIQUE NOT NULL,
    branch_id UUID NOT NULL REFERENCES public.branches(id) ON DELETE CASCADE,
    status TEXT NOT NULL CHECK (status IN ('draft', 'submitted', 'received', 'cancelled')) DEFAULT 'draft',
    total_amount NUMERIC(10,2) NOT NULL DEFAULT 0.00,
    created_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- PURCHASE ORDER ITEMS
CREATE TABLE IF NOT EXISTS public.purchase_order_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    po_id UUID NOT NULL REFERENCES public.purchase_orders(id) ON DELETE CASCADE,
    drug_id UUID NOT NULL REFERENCES public.drugs(id) ON DELETE CASCADE,
    quantity_requested INT NOT NULL DEFAULT 0,
    quantity_received INT NOT NULL DEFAULT 0,
    unit_cost NUMERIC(10,2) NOT NULL DEFAULT 0.00
);

-- TRANSACTIONS
CREATE TABLE IF NOT EXISTS public.transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    branch_id UUID NOT NULL REFERENCES public.branches(id) ON DELETE CASCADE,
    drug_id UUID NOT NULL REFERENCES public.drugs(id) ON DELETE CASCADE,
    transaction_type TEXT NOT NULL CHECK (transaction_type IN ('sale', 'receipt', 'adjustment', 'transfer')),
    quantity INT NOT NULL,
    unit_price NUMERIC(10,2) NOT NULL DEFAULT 0.00,
    total_amount NUMERIC(10,2) NOT NULL DEFAULT 0.00,
    user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    transaction_date TIMESTAMPTZ DEFAULT now()
);

-- 3. ROW LEVEL SECURITY (RLS) POLICIES

ALTER TABLE public.branches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.drugs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.purchase_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.purchase_order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;

-- Allow anon and authenticated full access for prototype demo
DROP POLICY IF EXISTS "Anon branches read/write" ON public.branches;
CREATE POLICY "Anon branches read/write" ON public.branches FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Anon users read/write" ON public.users;
CREATE POLICY "Anon users read/write" ON public.users FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Anon drugs read/write" ON public.drugs;
CREATE POLICY "Anon drugs read/write" ON public.drugs FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Anon inventory read/write" ON public.inventory;
CREATE POLICY "Anon inventory read/write" ON public.inventory FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Anon purchase_orders read/write" ON public.purchase_orders;
CREATE POLICY "Anon purchase_orders read/write" ON public.purchase_orders FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Anon purchase_order_items read/write" ON public.purchase_order_items;
CREATE POLICY "Anon purchase_order_items read/write" ON public.purchase_order_items FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Anon transactions read/write" ON public.transactions;
CREATE POLICY "Anon transactions read/write" ON public.transactions FOR ALL USING (true) WITH CHECK (true);


-- 4. ALGORITHM 1: ABC ANALYSIS FUNCTION (30-DAY SALES VELOCITY)

CREATE OR REPLACE FUNCTION public.get_abc_classification(
    p_branch_id UUID DEFAULT NULL,
    p_days INT DEFAULT 30
)
RETURNS TABLE (
    drug_id UUID,
    sku TEXT,
    name TEXT,
    category TEXT,
    bin_location TEXT,
    total_sold BIGINT,
    current_stock BIGINT,
    abc_class TEXT,
    min_threshold INT,
    max_threshold INT,
    unit_price NUMERIC,
    cost_price NUMERIC
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_total_sales_all BIGINT;
BEGIN
    -- Get total sales volume across all drugs in time window
    SELECT COALESCE(SUM(t.quantity), 0) INTO v_total_sales_all
    FROM public.transactions t
    WHERE t.transaction_type = 'sale'
      AND t.transaction_date >= (now() - (p_days || ' days')::INTERVAL)
      AND (p_branch_id IS NULL OR t.branch_id = p_branch_id);

    RETURN QUERY
    WITH sales_summary AS (
        SELECT 
            d.id AS d_id,
            d.sku AS d_sku,
            d.name AS d_name,
            d.category AS d_category,
            d.bin_location AS d_bin,
            d.min_threshold AS d_min,
            d.max_threshold AS d_max,
            d.unit_price AS d_uprice,
            d.cost_price AS d_cprice,
            COALESCE(SUM(t.quantity), 0) AS total_qty_sold
        FROM public.drugs d
        LEFT JOIN public.transactions t ON d.id = t.drug_id 
            AND t.transaction_type = 'sale'
            AND t.transaction_date >= (now() - (p_days || ' days')::INTERVAL)
            AND (p_branch_id IS NULL OR t.branch_id = p_branch_id)
        GROUP BY d.id, d.sku, d.name, d.category, d.bin_location, d.min_threshold, d.max_threshold, d.unit_price, d.cost_price
    ),
    stock_summary AS (
        SELECT 
            i.drug_id AS d_id,
            COALESCE(SUM(i.quantity), 0) AS stock_qty
        FROM public.inventory i
        WHERE (p_branch_id IS NULL OR i.branch_id = p_branch_id)
        GROUP BY i.drug_id
    ),
    ranked_sales AS (
        SELECT 
            s.d_id,
            s.d_sku,
            s.d_name,
            s.d_category,
            s.d_bin,
            s.total_qty_sold,
            COALESCE(st.stock_qty, 0) AS stock_qty,
            s.d_min,
            s.d_max,
            s.d_uprice,
            s.d_cprice,
            SUM(s.total_qty_sold) OVER (ORDER BY s.total_qty_sold DESC, s.d_name ASC) AS running_total
        FROM sales_summary s
        LEFT JOIN stock_summary st ON s.d_id = st.d_id
    )
    SELECT 
        r.d_id AS drug_id,
        r.d_sku AS sku,
        r.d_name AS name,
        r.d_category AS category,
        r.d_bin AS bin_location,
        r.total_qty_sold AS total_sold,
        r.stock_qty AS current_stock,
        CASE 
            WHEN r.total_qty_sold = 0 THEN 'Dead'
            WHEN v_total_sales_all > 0 AND (r.running_total::NUMERIC / v_total_sales_all::NUMERIC) <= 0.70 THEN 'Fast'
            ELSE 'Steady'
        END AS abc_class,
        r.d_min AS min_threshold,
        r.d_max AS max_threshold,
        r.d_uprice AS unit_price,
        r.d_cprice AS cost_price
    FROM ranked_sales r
    ORDER BY r.total_qty_sold DESC, r.d_name ASC;
END;
$$;


-- 5. ALGORITHM 2: SMART REPLENISHMENT AUTO-DRAFT PO FUNCTION

CREATE OR REPLACE FUNCTION public.auto_draft_purchase_orders(
    p_branch_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_target_branch_id UUID;
    v_new_po_id UUID;
    v_po_number TEXT;
    v_items_count INT := 0;
    v_total_cost NUMERIC(10,2) := 0.00;
BEGIN
    -- Select first branch if not specified
    IF p_branch_id IS NULL THEN
        SELECT id INTO v_target_branch_id FROM public.branches ORDER BY created_at ASC LIMIT 1;
    ELSE
        v_target_branch_id := p_branch_id;
    END IF;

    IF v_target_branch_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'No branch found');
    END IF;

    -- Generate unique PO number
    v_po_number := 'PO-' || to_char(now(), 'YYYYMMDD') || '-' || upper(substr(md5(random()::text), 1, 4));

    -- Create new Purchase Order record in draft status
    INSERT INTO public.purchase_orders (po_number, branch_id, status, total_amount)
    VALUES (v_po_number, v_target_branch_id, 'draft', 0.00)
    RETURNING id INTO v_new_po_id;

    -- Identify items below minimum threshold and add to PO items
    WITH low_stock AS (
        SELECT 
            d.id AS drug_id,
            COALESCE(SUM(i.quantity), 0) AS current_stock,
            d.min_threshold,
            d.max_threshold,
            d.cost_price
        FROM public.drugs d
        LEFT JOIN public.inventory i ON d.id = i.drug_id AND i.branch_id = v_target_branch_id
        GROUP BY d.id, d.min_threshold, d.max_threshold, d.cost_price
        HAVING COALESCE(SUM(i.quantity), 0) < d.min_threshold
    )
    INSERT INTO public.purchase_order_items (po_id, drug_id, quantity_requested, quantity_received, unit_cost)
    SELECT 
        v_new_po_id,
        ls.drug_id,
        GREATEST(ls.max_threshold - ls.current_stock, 10),
        0,
        ls.cost_price
    FROM low_stock ls;

    GET DIAGNOSTICS v_items_count = ROW_COUNT;

    -- Calculate total PO amount
    SELECT COALESCE(SUM(quantity_requested * unit_cost), 0.00) INTO v_total_cost
    FROM public.purchase_order_items
    WHERE po_id = v_new_po_id;

    -- Update total amount in purchase orders
    UPDATE public.purchase_orders 
    SET total_amount = v_total_cost 
    WHERE id = v_new_po_id;

    RETURN jsonb_build_object(
        'success', true,
        'po_id', v_new_po_id,
        'po_number', v_po_number,
        'items_added', v_items_count,
        'total_amount', v_total_cost
    );
END;
$$;


-- 6. SEED DEMO DATA

DO $$
DECLARE
    v_b1 UUID;
    v_b2 UUID;
    v_b3 UUID;
    v_d1 UUID; v_d2 UUID; v_d3 UUID; v_d4 UUID; v_d5 UUID;
    v_d6 UUID; v_d7 UUID; v_d8 UUID; v_d9 UUID; v_d10 UUID;
BEGIN
    -- Clean existing tables for clean seed
    TRUNCATE public.transactions, public.purchase_order_items, public.purchase_orders, public.inventory, public.users, public.drugs, public.branches CASCADE;

    -- Insert Branches
    INSERT INTO public.branches (name, code, location) VALUES 
    ('Downtown Central (HQ)', 'BR-HQ-01', '100 Main St, Metro City'),
    ('Westside Mega Store', 'BR-WS-02', '450 West Ave, Commerce District'),
    ('Northside Express Hub', 'BR-NS-03', '78 North Blvd, Suburbia')
    RETURNING id INTO v_b1;

    SELECT id INTO v_b2 FROM public.branches WHERE code = 'BR-WS-02';
    SELECT id INTO v_b3 FROM public.branches WHERE code = 'BR-NS-03';

    -- Insert Users
    INSERT INTO public.users (email, full_name, role, branch_id) VALUES
    ('ceo@pharmacy.com', 'Eleanor Vance', 'CEO', v_b1),
    ('manager.west@pharmacy.com', 'Marcus Brody', 'Manager', v_b2),
    ('pharmacist.north@pharmacy.com', 'Sarah Connor', 'Pharmacist', v_b3),
    ('storekeeper@pharmacy.com', 'Dave Bowman', 'Storekeeper', v_b1);

    -- Insert Drugs
    INSERT INTO public.drugs (sku, name, generic_name, category, unit, bin_location, unit_price, cost_price, min_threshold, max_threshold) VALUES
    ('DRUG-AMX-500', 'Amoxicillin 500mg Caps', 'Amoxicillin Trihydrate', 'Antibiotics', 'Box of 100', 'AISLE 1 - SHELF A2', 24.50, 14.00, 20, 150) RETURNING id INTO v_d1;
    INSERT INTO public.drugs (sku, name, generic_name, category, unit, bin_location, unit_price, cost_price, min_threshold, max_threshold) VALUES
    ('DRUG-PCT-500', 'Paracetamol 500mg Extra', 'Acetaminophen', 'Analgesics', 'Pack of 24', 'AISLE 1 - SHELF B1', 8.99, 4.20, 50, 300) RETURNING id INTO v_d2;
    INSERT INTO public.drugs (sku, name, generic_name, category, unit, bin_location, unit_price, cost_price, min_threshold, max_threshold) VALUES
    ('DRUG-IBU-400', 'Ibuprofen 400mg Forte', 'Ibuprofen', 'NSAID / Pain Relief', 'Box of 30', 'AISLE 2 - SHELF A1', 12.49, 6.80, 30, 200) RETURNING id INTO v_d3;
    INSERT INTO public.drugs (sku, name, generic_name, category, unit, bin_location, unit_price, cost_price, min_threshold, max_threshold) VALUES
    ('DRUG-MET-500', 'Metformin 500mg ER', 'Metformin HCl', 'Antidiabetic', 'Bottle of 90', 'AISLE 3 - SHELF C2', 18.75, 9.50, 15, 100) RETURNING id INTO v_d4;
    INSERT INTO public.drugs (sku, name, generic_name, category, unit, bin_location, unit_price, cost_price, min_threshold, max_threshold) VALUES
    ('DRUG-ATO-20', 'Atorvastatin 20mg', 'Atorvastatin Calcium', 'Cardiovascular', 'Box of 28', 'AISLE 3 - SHELF D1', 32.00, 17.50, 10, 80) RETURNING id INTO v_d5;
    INSERT INTO public.drugs (sku, name, generic_name, category, unit, bin_location, unit_price, cost_price, min_threshold, max_threshold) VALUES
    ('DRUG-OMP-20', 'Omeprazole 20mg Delayed', 'Omeprazole', 'Gastrointestinal', 'Box of 14', 'AISLE 2 - SHELF B3', 15.20, 7.90, 25, 120) RETURNING id INTO v_d6;
    INSERT INTO public.drugs (sku, name, generic_name, category, unit, bin_location, unit_price, cost_price, min_threshold, max_threshold) VALUES
    ('DRUG-AZI-250', 'Azithromycin 250mg Z-Pak', 'Azithromycin', 'Antibiotics', 'Pack of 6', 'AISLE 1 - SHELF A4', 29.99, 16.00, 15, 60) RETURNING id INTO v_d7;
    INSERT INTO public.drugs (sku, name, generic_name, category, unit, bin_location, unit_price, cost_price, min_threshold, max_threshold) VALUES
    ('DRUG-CET-10', 'Cetirizine 10mg Allergy', 'Cetirizine HCl', 'Antihistamine', 'Box of 30', 'AISLE 4 - SHELF A1', 9.50, 4.00, 20, 100) RETURNING id INTO v_d8;
    INSERT INTO public.drugs (sku, name, generic_name, category, unit, bin_location, unit_price, cost_price, min_threshold, max_threshold) VALUES
    ('DRUG-INS-100', 'Insulin Glargine 100U/ml', 'Insulin Glargine', 'Endocrine', 'Vial 10ml', 'REFRIGERATOR - BAY 1', 85.00, 52.00, 5, 25) RETURNING id INTO v_d9;
    INSERT INTO public.drugs (sku, name, generic_name, category, unit, bin_location, unit_price, cost_price, min_threshold, max_threshold) VALUES
    ('DRUG-VIT-1000', 'Vitamin C 1000mg Efferv', 'Ascorbic Acid', 'Vitamins & Supplements', 'Tube of 20', 'AISLE 5 - SHELF E2', 11.00, 5.20, 40, 200) RETURNING id INTO v_d10;

    -- Insert Inventory per Branch
    -- HQ Branch
    INSERT INTO public.inventory (branch_id, drug_id, quantity, batch_number, expiry_date) VALUES
    (v_b1, v_d1, 85, 'BATCH-AMX-001', '2027-11-30'),
    (v_b1, v_d2, 140, 'BATCH-PCT-102', '2028-05-15'),
    (v_b1, v_d3, 8, 'BATCH-IBU-055', '2027-02-28'), -- Below min threshold (30)!
    (v_b1, v_d4, 45, 'BATCH-MET-881', '2027-09-10'),
    (v_b1, v_d5, 30, 'BATCH-ATO-441', '2026-12-31'),
    (v_b1, v_d6, 5, 'BATCH-OMP-112', '2027-04-20'), -- Below min threshold (25)!
    (v_b1, v_d7, 12, 'BATCH-AZI-901', '2027-01-15'), -- Below min threshold (15)!
    (v_b1, v_d8, 60, 'BATCH-CET-332', '2028-08-10'),
    (v_b1, v_d9, 18, 'BATCH-INS-700', '2026-10-31'),
    (v_b1, v_d10, 110, 'BATCH-VIT-500', '2028-12-01');

    -- Westside Branch
    INSERT INTO public.inventory (branch_id, drug_id, quantity, batch_number, expiry_date) VALUES
    (v_b2, v_d1, 120, 'BATCH-AMX-002', '2027-11-30'),
    (v_b2, v_d2, 220, 'BATCH-PCT-103', '2028-05-15'),
    (v_b2, v_d3, 65, 'BATCH-IBU-056', '2027-02-28'),
    (v_b2, v_d5, 6, 'BATCH-ATO-442', '2026-12-31'), -- Low stock
    (v_b2, v_d8, 90, 'BATCH-CET-333', '2028-08-10');

    -- Northside Branch
    INSERT INTO public.inventory (branch_id, drug_id, quantity, batch_number, expiry_date) VALUES
    (v_b3, v_d2, 180, 'BATCH-PCT-104', '2028-05-15'),
    (v_b3, v_d4, 50, 'BATCH-MET-882', '2027-09-10'),
    (v_b3, v_d9, 3, 'BATCH-INS-701', '2026-10-31');

    -- Insert Sales Transactions (Past 30 Days) for ABC Velocity Classification
    -- Fast stock items: Paracetamol, Amoxicillin, Ibuprofen
    INSERT INTO public.transactions (branch_id, drug_id, transaction_type, quantity, unit_price, total_amount, transaction_date) VALUES
    (v_b1, v_d2, 'sale', 120, 8.99, 1078.80, now() - INTERVAL '2 days'),
    (v_b1, v_d2, 'sale', 95, 8.99, 854.05, now() - INTERVAL '5 days'),
    (v_b1, v_d1, 'sale', 60, 24.50, 1470.00, now() - INTERVAL '3 days'),
    (v_b1, v_d1, 'sale', 45, 24.50, 1102.50, now() - INTERVAL '10 days'),
    (v_b1, v_d3, 'sale', 40, 12.49, 499.60, now() - INTERVAL '4 days'),
    (v_b1, v_d4, 'sale', 25, 18.75, 468.75, now() - INTERVAL '8 days'),
    (v_b1, v_d5, 'sale', 15, 32.00, 480.00, now() - INTERVAL '12 days'),
    (v_b1, v_d6, 'sale', 18, 15.20, 273.60, now() - INTERVAL '14 days'),
    (v_b1, v_d8, 'sale', 30, 9.50, 285.00, now() - INTERVAL '15 days');

    -- Westside sales
    INSERT INTO public.transactions (branch_id, drug_id, transaction_type, quantity, unit_price, total_amount, transaction_date) VALUES
    (v_b2, v_d2, 'sale', 150, 8.99, 1348.50, now() - INTERVAL '1 day'),
    (v_b2, v_d1, 'sale', 80, 24.50, 1960.00, now() - INTERVAL '4 days'),
    (v_b2, v_d3, 'sale', 50, 12.49, 624.50, now() - INTERVAL '6 days');

    -- Northside sales
    INSERT INTO public.transactions (branch_id, drug_id, transaction_type, quantity, unit_price, total_amount, transaction_date) VALUES
    (v_b3, v_d2, 'sale', 110, 8.99, 988.90, now() - INTERVAL '2 days'),
    (v_b3, v_d9, 'sale', 10, 85.00, 850.00, now() - INTERVAL '7 days');

    -- Note: DRUG-AZI-250 and DRUG-VIT-1000 have 0 sales in past 30 days -> DEAD STOCK!

END $$;
 
 - -   M A S T E R   C A R T O N S  
 C R E A T E   T A B L E   I F   N O T   E X I S T S   p u b l i c . m a s t e r _ c a r t o n s   (  
         i d   U U I D   P R I M A R Y   K E Y   D E F A U L T   g e n _ r a n d o m _ u u i d ( ) ,  
         c a r t o n _ b a r c o d e   T E X T   U N I Q U E   N O T   N U L L ,  
         d r u g _ i d   U U I D   N O T   N U L L   R E F E R E N C E S   p u b l i c . d r u g s ( i d )   O N   D E L E T E   C A S C A D E ,  
         r e t a i l _ q u a n t i t y _ m u l t i p l i e r   I N T   N O T   N U L L   D E F A U L T   1 ,  
         i m a g e _ u r l   T E X T ,  
         c r e a t e d _ a t   T I M E S T A M P T Z   D E F A U L T   n o w ( )  
 ) ;  
 
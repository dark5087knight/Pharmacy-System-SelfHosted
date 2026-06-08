-- ============================================================
-- PHARMACY SYSTEM - INDEX STRATEGY
-- ============================================================
-- Single-user system indexes optimized for quick reads
-- without tenant boundaries.
-- ============================================================

-- ── STAFF ────────────────────────────────────────────────────
CREATE UNIQUE INDEX idx_staff_username ON staff (username) WHERE deleted_at IS NULL;
CREATE        INDEX idx_staff_status ON staff (status);

-- ── CUSTOMERS ────────────────────────────────────────────────
CREATE        INDEX idx_customers_phone     ON customers (phone);
CREATE        INDEX idx_customers_email     ON customers (email) WHERE email IS NOT NULL;
CREATE        INDEX idx_customers_membership       ON customers (membership_level);
-- Fuzzy search on customer name
CREATE        INDEX idx_customers_name_trgm        ON customers USING gin (name gin_trgm_ops);

-- ── MEDICINES ────────────────────────────────────────────────
CREATE        INDEX idx_medicines_category  ON medicines (category_id);
CREATE        INDEX idx_medicines_supplier  ON medicines (supplier_id);
CREATE        INDEX idx_medicines_status    ON medicines (status);
CREATE        INDEX idx_medicines_expiry           ON medicines (expiry_date);
CREATE        INDEX idx_medicines_low_stock        ON medicines (quantity, low_stock_threshold)
                   WHERE deleted_at IS NULL;
-- Fuzzy search on medicine name / generic name
CREATE        INDEX idx_medicines_name_trgm        ON medicines USING gin (name gin_trgm_ops);
CREATE        INDEX idx_medicines_generic_trgm     ON medicines USING gin (generic_name gin_trgm_ops);

-- ── STOCK MOVEMENTS ──────────────────────────────────────────
CREATE        INDEX idx_stock_movements_date        ON stock_movements (created_at DESC);
CREATE        INDEX idx_stock_movements_medicine    ON stock_movements (medicine_id, created_at DESC);
CREATE        INDEX idx_stock_movements_reference   ON stock_movements (reference_type, reference_id)
                   WHERE reference_id IS NOT NULL;

-- ── SALES ────────────────────────────────────────────────────
CREATE        INDEX idx_sales_date                 ON sales (created_at DESC);
CREATE        INDEX idx_sales_customer      ON sales (customer_id) WHERE customer_id IS NOT NULL;
CREATE        INDEX idx_sales_cashier       ON sales (cashier_id);
CREATE        INDEX idx_sales_status        ON sales (status);

-- ── SALE ITEMS ───────────────────────────────────────────────
CREATE        INDEX idx_sale_items_sale            ON sale_items (sale_id);
CREATE        INDEX idx_sale_items_medicine        ON sale_items (medicine_id);

-- ── PAYMENTS ─────────────────────────────────────────────────
CREATE        INDEX idx_payments_sale              ON payments (sale_id);
CREATE        INDEX idx_payments_date              ON payments (paid_at DESC);

-- ── PURCHASE ORDERS ──────────────────────────────────────────
CREATE        INDEX idx_po_status           ON purchase_orders (status);
CREATE        INDEX idx_po_supplier         ON purchase_orders (supplier_id);
CREATE        INDEX idx_po_date             ON purchase_orders (created_at DESC);

-- ── PRESCRIPTIONS ────────────────────────────────────────────
CREATE        INDEX idx_prescriptions_customer     ON prescriptions (customer_id);
CREATE        INDEX idx_prescriptions_status       ON prescriptions (status);

-- ── NOTIFICATIONS ────────────────────────────────────────────
CREATE        INDEX idx_notifications_staff_unread ON notifications (staff_id, read)
                   WHERE read = FALSE;

-- ── ACTIVITIES ───────────────────────────────────────────────
CREATE        INDEX idx_activities_date            ON activities (created_at DESC);
CREATE        INDEX idx_activities_actor           ON activities (actor_id);

-- ── AUDIT LOGS ───────────────────────────────────────────────
CREATE        INDEX idx_audit_date                 ON audit_logs (created_at DESC);
CREATE        INDEX idx_audit_actor                ON audit_logs (actor_id);
CREATE        INDEX idx_audit_table_record         ON audit_logs (table_name, record_id);

-- ── ROLES / RBAC ─────────────────────────────────────────────
CREATE        INDEX idx_user_roles_staff           ON user_roles (staff_id);
CREATE        INDEX idx_user_roles_role            ON user_roles (role_id);
CREATE        INDEX idx_role_permissions_role      ON role_permissions (role_id);

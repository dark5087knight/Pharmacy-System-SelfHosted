-- ============================================================
-- PHARMACY SYSTEM - SINGLE-USER POSTGRESQL SCHEMA
-- Architecture: Single-User / Self-Hosted / No Row-Level Security
-- Target: AWS RDS PostgreSQL 15+ / local PostgreSQL 15+
-- ============================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";   -- fuzzy search on medicine names

-- ============================================================
-- SECTION 1: SETTINGS & RBAC TABLES
-- ============================================================

-- Pharmacy Settings (single-row table replacing tenants)
CREATE TABLE pharmacy_settings (
    id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name             VARCHAR(255) NOT NULL DEFAULT 'My Pharmacy',
    phone            VARCHAR(50),
    address          TEXT,
    country          CHAR(2) NOT NULL DEFAULT 'IQ',           -- ISO 3166-1 alpha-2
    timezone         VARCHAR(100) NOT NULL DEFAULT 'Asia/Baghdad',
    locale           VARCHAR(20) NOT NULL DEFAULT 'en',
    currency         CHAR(3) NOT NULL DEFAULT 'IQD',
    logo_url         TEXT,
    settings         JSONB NOT NULL DEFAULT '{}',             -- config settings
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Permissions catalogue (platform-wide)
CREATE TABLE permissions (
    id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code             VARCHAR(100) NOT NULL UNIQUE,            -- e.g. 'medicines.write'
    description      TEXT,
    module           VARCHAR(50) NOT NULL,                    -- 'medicines','sales','staff',...
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Roles (without tenant_id)
CREATE TABLE roles (
    id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name             VARCHAR(100) NOT NULL UNIQUE,
    description      TEXT,
    is_system        BOOLEAN NOT NULL DEFAULT FALSE,          -- built-in roles cannot be deleted
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Many-to-many: roles <-> permissions
CREATE TABLE role_permissions (
    role_id          UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    permission_id    UUID NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
    PRIMARY KEY (role_id, permission_id)
);

-- Staff / Users (without tenant_id, uses username instead of email, email optional)
CREATE TABLE staff (
    id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name             VARCHAR(255) NOT NULL,
    username         VARCHAR(100) NOT NULL UNIQUE,
    email            VARCHAR(255),
    phone            VARCHAR(50),
    password_hash    TEXT,
    status           VARCHAR(30) NOT NULL DEFAULT 'active'
                        CHECK (status IN ('active','inactive','suspended')),
    shift            VARCHAR(20) NOT NULL DEFAULT 'morning'
                        CHECK (shift IN ('morning','afternoon','night','flexible')),
    avatar_url       TEXT,
    joined_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_seen_at     TIMESTAMPTZ,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at       TIMESTAMPTZ
);

-- Many-to-many: staff <-> roles
CREATE TABLE user_roles (
    staff_id         UUID NOT NULL REFERENCES staff(id) ON DELETE CASCADE,
    role_id          UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    granted_by       UUID REFERENCES staff(id),
    granted_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (staff_id, role_id)
);

-- ============================================================
-- SECTION 2: CORE BUSINESS TABLES
-- ============================================================

-- Branches / locations
CREATE TABLE branches (
    id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name             VARCHAR(255) NOT NULL,
    address          TEXT,
    phone            VARCHAR(50),
    is_main          BOOLEAN NOT NULL DEFAULT FALSE,
    status           VARCHAR(20) NOT NULL DEFAULT 'active'
                        CHECK (status IN ('active','inactive')),
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Customers / Patients
CREATE TABLE customers (
    id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name             VARCHAR(255) NOT NULL,
    phone            VARCHAR(50) NOT NULL UNIQUE,
    email            VARCHAR(255),
    date_of_birth    DATE,
    gender           CHAR(1) CHECK (gender IN ('M','F','O')),
    loyalty_points   INTEGER NOT NULL DEFAULT 0 CHECK (loyalty_points >= 0),
    membership_level VARCHAR(30) NOT NULL DEFAULT 'standard'
                        CHECK (membership_level IN ('standard','silver','gold','platinum')),
    allergies        JSONB NOT NULL DEFAULT '[]',
    insurance_provider VARCHAR(255),
    insurance_policy   VARCHAR(255),
    balance          NUMERIC(12,2) NOT NULL DEFAULT 0,
    total_spent      NUMERIC(14,2) NOT NULL DEFAULT 0,
    visits           INTEGER NOT NULL DEFAULT 0,
    notes            TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at       TIMESTAMPTZ,
    created_by       UUID REFERENCES staff(id)
);

-- Suppliers
CREATE TABLE suppliers (
    id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name             VARCHAR(255) NOT NULL,
    company          VARCHAR(255) NOT NULL,
    email            VARCHAR(255),
    phone            VARCHAR(50),
    address          TEXT,
    rating           NUMERIC(3,2) NOT NULL DEFAULT 0
                        CHECK (rating >= 0 AND rating <= 5),
    outstanding_balance NUMERIC(14,2) NOT NULL DEFAULT 0,
    total_purchased  NUMERIC(14,2) NOT NULL DEFAULT 0,
    status           VARCHAR(20) NOT NULL DEFAULT 'active'
                        CHECK (status IN ('active','inactive','blacklisted')),
    notes            TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at       TIMESTAMPTZ,
    created_by       UUID REFERENCES staff(id)
);

-- Medicine Categories
CREATE TABLE medicine_categories (
    id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name             VARCHAR(100) NOT NULL UNIQUE,
    description      TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Medicines / Inventory Master
CREATE TABLE medicines (
    id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    branch_id        UUID REFERENCES branches(id),
    supplier_id      UUID REFERENCES suppliers(id),
    category_id      UUID REFERENCES medicine_categories(id),
    name             VARCHAR(255) NOT NULL,
    generic_name     VARCHAR(255) NOT NULL,
    brand            VARCHAR(255) NOT NULL,
    barcode          VARCHAR(100) UNIQUE,
    sku              VARCHAR(100) UNIQUE,
    batch_number     VARCHAR(100),
    manufacture_date DATE,
    expiry_date      DATE NOT NULL,
    quantity         INTEGER NOT NULL DEFAULT 0 CHECK (quantity >= 0),
    unit             VARCHAR(30) NOT NULL DEFAULT 'tablet',
    purchase_price   NUMERIC(12,4) NOT NULL DEFAULT 0,
    selling_price    NUMERIC(12,4) NOT NULL DEFAULT 0,
    discount         NUMERIC(5,2) NOT NULL DEFAULT 0 CHECK (discount >= 0 AND discount <= 100),
    tax_rate         NUMERIC(5,2) NOT NULL DEFAULT 0 CHECK (tax_rate >= 0),
    low_stock_threshold INTEGER NOT NULL DEFAULT 10,
    rack             VARCHAR(50),
    shelf            VARCHAR(50),
    warehouse        VARCHAR(100),
    status           VARCHAR(20) NOT NULL DEFAULT 'active'
                        CHECK (status IN ('active','inactive','discontinued','recalled')),
    controlled       BOOLEAN NOT NULL DEFAULT FALSE,
    prescription_required BOOLEAN NOT NULL DEFAULT FALSE,
    is_pinned        BOOLEAN NOT NULL DEFAULT FALSE,
    description      TEXT,
    side_effects     JSONB NOT NULL DEFAULT '[]',
    interactions     JSONB NOT NULL DEFAULT '[]',
    dosage           VARCHAR(255),
    storage          VARCHAR(255),
    image_url        TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at       TIMESTAMPTZ,
    created_by       UUID REFERENCES staff(id),
    updated_by       UUID REFERENCES staff(id)
);

-- Stock Movement Log (inventory in/out audit trail)
CREATE TABLE stock_movements (
    id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    medicine_id      UUID NOT NULL REFERENCES medicines(id),
    movement_type    VARCHAR(30) NOT NULL
                        CHECK (movement_type IN (
                            'purchase','sale','adjustment','return',
                            'transfer','expiry_write_off','recall'
                        )),
    quantity_before  INTEGER NOT NULL,
    quantity_change  INTEGER NOT NULL,   -- positive = in, negative = out
    quantity_after   INTEGER NOT NULL,
    reference_id     UUID,               -- points to sale_id, purchase_order_id, etc.
    reference_type   VARCHAR(50),        -- 'sale','purchase_order','adjustment'
    notes            TEXT,
    performed_by     UUID REFERENCES staff(id),
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Prescriptions
CREATE TABLE prescriptions (
    id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id      UUID NOT NULL REFERENCES customers(id),
    doctor_name      VARCHAR(255) NOT NULL,
    doctor_license   VARCHAR(100),
    issued_at        TIMESTAMPTZ NOT NULL,
    status           VARCHAR(30) NOT NULL DEFAULT 'pending'
                        CHECK (status IN ('pending','verified','dispensed','expired','rejected')),
    image_url        TEXT,
    notes            TEXT,
    refills_remaining INTEGER NOT NULL DEFAULT 0 CHECK (refills_remaining >= 0),
    verified_by      UUID REFERENCES staff(id),
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by       UUID REFERENCES staff(id)
);

-- Prescription line items
CREATE TABLE prescription_items (
    id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    prescription_id  UUID NOT NULL REFERENCES prescriptions(id) ON DELETE CASCADE,
    medicine_id      UUID NOT NULL REFERENCES medicines(id),
    quantity         INTEGER NOT NULL CHECK (quantity > 0),
    dosage           VARCHAR(255) NOT NULL,
    instructions     TEXT
);

-- Sales / Invoices
CREATE TABLE sales (
    id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    branch_id        UUID REFERENCES branches(id),
    invoice_number   VARCHAR(50) NOT NULL UNIQUE,
    customer_id      UUID REFERENCES customers(id),
    cashier_id       UUID NOT NULL REFERENCES staff(id),
    prescription_id  UUID REFERENCES prescriptions(id),
    subtotal         NUMERIC(14,2) NOT NULL DEFAULT 0,
    discount         NUMERIC(14,2) NOT NULL DEFAULT 0,
    tax              NUMERIC(14,2) NOT NULL DEFAULT 0,
    total            NUMERIC(14,2) NOT NULL DEFAULT 0,
    payment_method   VARCHAR(30) NOT NULL
                        CHECK (payment_method IN ('cash','card','insurance','wallet','credit')),
    status           VARCHAR(30) NOT NULL DEFAULT 'completed'
                        CHECK (status IN ('draft','completed','refunded','void')),
    notes            TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Sale line items
CREATE TABLE sale_items (
    id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sale_id          UUID NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
    medicine_id      UUID NOT NULL REFERENCES medicines(id),
    name             VARCHAR(255) NOT NULL,       -- denormalized snapshot at time of sale
    quantity         INTEGER NOT NULL CHECK (quantity > 0),
    unit_price       NUMERIC(12,4) NOT NULL,
    discount         NUMERIC(5,2) NOT NULL DEFAULT 0,
    tax_rate         NUMERIC(5,2) NOT NULL DEFAULT 0,
    line_total       NUMERIC(14,2) NOT NULL
);

-- Payments (separate from sales for split payments / insurance claims)
CREATE TABLE payments (
    id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sale_id          UUID NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
    amount           NUMERIC(14,2) NOT NULL,
    method           VARCHAR(30) NOT NULL
                        CHECK (method IN ('cash','card','insurance','wallet','credit')),
    status           VARCHAR(20) NOT NULL DEFAULT 'completed'
                        CHECK (status IN ('pending','completed','failed','refunded')),
    reference        VARCHAR(255),               -- card auth, insurance claim #
    paid_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by       UUID REFERENCES staff(id),
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Purchase Orders
CREATE TABLE purchase_orders (
    id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    po_number        VARCHAR(50) NOT NULL UNIQUE,
    supplier_id      UUID NOT NULL REFERENCES suppliers(id),
    status           VARCHAR(30) NOT NULL DEFAULT 'draft'
                        CHECK (status IN ('draft','sent','partial','received','cancelled')),
    total            NUMERIC(14,2) NOT NULL DEFAULT 0,
    notes            TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expected_at      TIMESTAMPTZ,
    received_at      TIMESTAMPTZ,
    created_by       UUID REFERENCES staff(id),
    approved_by      UUID REFERENCES staff(id)
);

-- Purchase Order line items
CREATE TABLE purchase_order_items (
    id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    purchase_order_id UUID NOT NULL REFERENCES purchase_orders(id) ON DELETE CASCADE,
    medicine_id      UUID NOT NULL REFERENCES medicines(id),
    quantity_ordered INTEGER NOT NULL CHECK (quantity_ordered > 0),
    quantity_received INTEGER NOT NULL DEFAULT 0,
    unit_cost        NUMERIC(12,4) NOT NULL,
    line_total       NUMERIC(14,2) NOT NULL
);

-- Notifications (per staff member or broadcast)
CREATE TABLE notifications (
    id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    staff_id         UUID REFERENCES staff(id),              -- NULL = broadcast to all
    title            VARCHAR(255) NOT NULL,
    body             TEXT NOT NULL,
    category         VARCHAR(50) NOT NULL,
    priority         VARCHAR(20) NOT NULL DEFAULT 'normal'
                        CHECK (priority IN ('low','normal','high','critical')),
    read             BOOLEAN NOT NULL DEFAULT FALSE,
    read_at          TIMESTAMPTZ,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Activities / Event log
CREATE TABLE activities (
    id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    type             VARCHAR(100) NOT NULL,
    message          TEXT NOT NULL,
    actor_id         UUID REFERENCES staff(id),
    severity         VARCHAR(20) NOT NULL DEFAULT 'info'
                        CHECK (severity IN ('debug','info','warning','error','critical')),
    metadata         JSONB NOT NULL DEFAULT '{}',
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Audit Logs (immutable, never update/delete)
CREATE TABLE audit_logs (
    id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    actor_id         UUID REFERENCES staff(id),
    action           VARCHAR(100) NOT NULL,     -- 'CREATE','UPDATE','DELETE','LOGIN',...
    table_name       VARCHAR(100) NOT NULL,
    record_id        UUID,
    old_values       JSONB,
    new_values       JSONB,
    ip_address       INET,
    user_agent       TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- SECTION 3: UPDATED_AT TRIGGER FUNCTION
-- ============================================================

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

-- Apply updated_at trigger to all relevant tables
DO $$
DECLARE
    t TEXT;
BEGIN
    FOREACH t IN ARRAY ARRAY[
        'pharmacy_settings','roles','staff',
        'branches','customers','suppliers','medicine_categories',
        'medicines','prescriptions','sales','purchase_orders'
    ] LOOP
        EXECUTE format(
            'CREATE TRIGGER trg_%s_updated_at
             BEFORE UPDATE ON %I
             FOR EACH ROW EXECUTE FUNCTION set_updated_at();',
             t, t
        );
    END LOOP;
END;
$$;

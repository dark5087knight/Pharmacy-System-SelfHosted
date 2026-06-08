"""initial schema

Revision ID: 001_initial_schema
Revises: 
Create Date: 2026-05-23

"""
import os
from alembic import op
from sqlalchemy import text

# revision identifiers, used by Alembic.
revision = '001_initial_schema'
down_revision = None
branch_labels = None
depends_on = None

# Locate the SQL directory relative to this migration file
SQL_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", "SQL"))

def run_sql_file(filepath: str):
    if not os.path.exists(filepath):
        raise FileNotFoundError(f"SQL file not found at {filepath}")
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()
    
    connection = op.get_bind()
    try:
        connection.execute(text(content))
    except Exception as e:
        import traceback
        print("\n" + "="*80)
        print(f"SQL EXECUTION FAILED FOR FILE: {filepath}")
        print(f"Error class: {e.__class__}")
        print(f"Error message: {str(e)}")
        if hasattr(e, 'orig'):
            print(f"Underlying driver error: {repr(e.orig)}")
        print("="*80 + "\n")
        raise e

def upgrade() -> None:
    # 1. Run 01_schema.sql
    run_sql_file(os.path.join(SQL_DIR, "01_schema.sql"))
    
    # 2. Run 02_rls_policies.sql
    run_sql_file(os.path.join(SQL_DIR, "02_rls_policies.sql"))
    
    # 3. Run 03_indexes.sql
    run_sql_file(os.path.join(SQL_DIR, "03_indexes.sql"))

def downgrade() -> None:
    # Drop all tables in reverse dependency order
    tables = [
        "audit_logs", 
        "activities", 
        "notifications", 
        "purchase_order_items", 
        "purchase_orders",
        "payments", 
        "sale_items", 
        "sales", 
        "prescription_items", 
        "prescriptions",
        "stock_movements", 
        "medicines", 
        "medicine_categories", 
        "suppliers", 
        "customers",
        "branches", 
        "user_roles", 
        "staff", 
        "role_permissions", 
        "roles", 
        "permissions",
        "subscriptions", 
        "tenants", 
        "plans"
    ]
    for table in tables:
        op.execute(f"DROP TABLE IF EXISTS {table} CASCADE")
    
    # Drop custom triggers/functions/roles
    op.execute("DROP FUNCTION IF EXISTS set_updated_at() CASCADE")
    op.execute("DROP FUNCTION IF EXISTS current_tenant_id() CASCADE")
    op.execute("DROP FUNCTION IF EXISTS current_staff_id() CASCADE")

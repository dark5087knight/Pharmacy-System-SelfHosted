import asyncio
import sys
import os
import uuid
import json
from datetime import datetime, timezone, timedelta
import openpyxl
from sqlalchemy import select, insert

# Add backend root to path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from app.shared.database import AsyncSessionLocal, engine
from app.models import Branch, MedicineCategory, Medicine

def clean_barcode(val):
    if val is None:
        return None
    val_str = str(val).strip()
    if not val_str:
        return None
    # If multiple barcodes are comma-separated, take the first one
    if "," in val_str:
        val_str = val_str.split(",")[0].strip()
    
    if val_str.endswith(".0"):
        val_str = val_str[:-2]
    if "e+" in val_str.lower():
        try:
            val_str = str(int(float(val_str)))
        except ValueError:
            pass
    return val_str[:100]  # Truncate to maximum VARCHAR(100) limit

async def seed_inventory():
    excel_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "pharmacy items (2).xlsx"))
    if not os.path.exists(excel_path):
        print(f"Error: Excel file not found at {excel_path}")
        return
        
    print(f"Opening Excel file: {excel_path}...")
    wb = openpyxl.load_workbook(excel_path, read_only=True)
    sheet = wb.active
    
    print("Reading rows from Excel...")
    rows_iterator = sheet.iter_rows(values_only=True)
    
    header = next(rows_iterator, None)
    if not header:
        print("Error: Excel file is empty.")
        return
        
    print(f"Found headers: {header}")
    
    async with AsyncSessionLocal() as db:
        # Retrieve the first branch to assign medicines to it
        branch_res = await db.execute(select(Branch))
        branch = branch_res.scalars().first()
        if not branch:
            print("Error: No branch found in the database. Please seed the database structure first using setup_senare.py.")
            return
        branch_id = branch.id
        print(f"Assigning medicines to branch: '{branch.name}' (ID: {branch_id})")
        
        # Retrieve existing categories to prevent duplicates
        category_res = await db.execute(select(MedicineCategory))
        existing_categories = category_res.scalars().all()
        category_map = {c.name.strip().lower(): c.id for c in existing_categories}
        
        seen_barcodes = set()
        seen_ids = set()
        new_categories_to_insert = []
        new_category_names_added = set()
        
        medicines_to_insert = []
        
        print("Parsing rows...")
        row_count = 0
        skipped_count = 0
        
        for row in rows_iterator:
            if not row or row[0] is None:
                continue
                
            raw_id = str(row[0]).strip()
            try:
                parsed_id = uuid.UUID(raw_id)
            except ValueError:
                skipped_count += 1
                continue
                
            # Prevent PK duplicate
            if parsed_id in seen_ids:
                skipped_count += 1
                continue
            seen_ids.add(parsed_id)
            
            full_name = str(row[1]).strip() if row[1] else "Unknown Medicine"
            full_name = full_name[:255] # VARCHAR(255)
            
            barcode = clean_barcode(row[2])
            
            # Prevent barcode duplicate
            if barcode:
                if barcode in seen_barcodes:
                    # Clear barcode to avoid UniqueViolation
                    barcode = None
                else:
                    seen_barcodes.add(barcode)
                    
            unit = str(row[3]).strip() if row[3] else (str(row[7]).strip() if row[7] else "علبة")
            unit = unit[:30] # VARCHAR(30)
            
            company = str(row[4]).strip() if row[4] else None
            if company:
                company = company[:255] # VARCHAR(255)
            
            # Parse indication list
            indication_val = row[5]
            indication = []
            if indication_val:
                try:
                    if isinstance(indication_val, str):
                        parsed = json.loads(indication_val)
                        if isinstance(parsed, list):
                            indication = [str(x).strip() for x in parsed]
                    elif isinstance(indication_val, list):
                        indication = [str(x).strip() for x in indication_val]
                except Exception:
                    indication = [str(indication_val).strip()]
            
            dose = str(row[6]).strip() if row[6] else None
            if dose:
                dose = dose[:255] # VARCHAR(255)
                
            small_unit = str(row[8]).strip() if row[8] else None
            if small_unit:
                small_unit = small_unit[:100] # VARCHAR(100)
            
            equivalency = None
            if row[9] is not None:
                try:
                    equivalency = int(float(str(row[9]).strip()))
                except ValueError:
                    pass
            
            # Category resolution
            cat_name = "General"
            if indication:
                cat_name = indication[0].strip()
                if not cat_name:
                    cat_name = "General"
            
            # Truncate category name to 100 characters as defined by VARCHAR(100) in medicine_categories
            cat_name = cat_name[:100]
            
            cat_key = cat_name.lower().strip()
            if cat_key not in category_map:
                if cat_key not in new_category_names_added:
                    cat_id = uuid.uuid4()
                    category_map[cat_key] = cat_id
                    new_categories_to_insert.append({
                        "id": cat_id,
                        "name": cat_name,
                        "description": f"Category for {cat_name}",
                        "created_at": datetime.now(timezone.utc),
                        "updated_at": datetime.now(timezone.utc)
                    })
                    new_category_names_added.add(cat_key)
            
            cat_id = category_map[cat_key]
            
            brand = full_name.split()[0] if full_name else (company or "General")
            brand = brand[:255] # VARCHAR(255)
            
            sku = f"SKU-{parsed_id.hex[:12]}"
            
            medicines_to_insert.append({
                "id": parsed_id,
                "branch_id": branch_id,
                "category_id": cat_id,
                "name": full_name,
                "generic_name": full_name,
                "brand": brand,
                "barcode": barcode,
                "sku": sku,
                "batch_number": "BATCH-001",
                "manufacture_date": datetime.now(timezone.utc).date() - timedelta(days=180),
                "expiry_date": datetime.now(timezone.utc).date() + timedelta(days=730),
                "quantity": 100,
                "unit": unit,
                "purchase_price": 10.0,
                "selling_price": 15.0,
                "discount": 0.0,
                "tax_rate": 0.0,
                "low_stock_threshold": 10,
                "status": "active",
                "controlled": False,
                "prescription_required": False,
                "is_pinned": False,
                "side_effects": [],
                "interactions": [],
                "company": company,
                "indication": indication,
                "dose": dose,
                "small_unit": small_unit,
                "equivalency": equivalency,
                "created_at": datetime.now(timezone.utc),
                "updated_at": datetime.now(timezone.utc)
            })
            row_count += 1
            
        print(f"Parsing complete. Ready to insert {row_count} items (skipped {skipped_count} invalid/duplicate rows).")
        
        # 1. Bulk Insert new categories
        if new_categories_to_insert:
            print(f"Bulk inserting {len(new_categories_to_insert)} new categories...")
            await db.execute(insert(MedicineCategory), new_categories_to_insert)
            await db.commit()
            print("Categories inserted.")
            
        # 2. Bulk Insert medicines in chunks of 5000
        chunk_size = 5000
        print(f"Bulk inserting {len(medicines_to_insert)} medicines in chunks of {chunk_size}...")
        for i in range(0, len(medicines_to_insert), chunk_size):
            chunk = medicines_to_insert[i:i + chunk_size]
            await db.execute(insert(Medicine), chunk)
            print(f"Inserted chunk {i // chunk_size + 1} ({len(chunk)} rows)...")
            
        await db.commit()
        print("\nAll database changes committed successfully!")
        print(f"Successfully seeded {row_count} items into the medicines table.")

async def main():
    start_time = datetime.now()
    await seed_inventory()
    end_time = datetime.now()
    print(f"Time taken: {end_time - start_time}")

if __name__ == "__main__":
    asyncio.run(main())

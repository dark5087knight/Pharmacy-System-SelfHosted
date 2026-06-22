import os
import sys
import subprocess
from sqlalchemy import create_engine, text
from sqlalchemy.engine.url import make_url

def parse_database_url():
    yaml_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), "config.yaml")
    if not os.path.exists(yaml_path):
        print(f"Error: config.yaml not found at {yaml_path}")
        sys.exit(1)
        
    db_url = None
    with open(yaml_path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if ":" in line:
                k, v = line.split(":", 1)
                if k.strip() == "DATABASE_URL":
                    v = v.strip()
                    if (v.startswith('"') and v.endswith('"')) or (v.startswith("'") and v.endswith("'")):
                        v = v[1:-1]
                    db_url = v
                    break
    if not db_url:
        print("Error: DATABASE_URL not found in config.yaml")
        sys.exit(1)
    return db_url

def main():
    db_url_str = parse_database_url()
    print(f"Parsed DATABASE_URL from config.yaml: {db_url_str}")
    
    url_obj = make_url(db_url_str)
    username = url_obj.username
    password = url_obj.password
    host = url_obj.host
    port = url_obj.port or 5432
    target_db = url_obj.database
    
    if not target_db:
        print("Error: Could not extract target database name from URL")
        sys.exit(1)
        
    print(f"Connecting to database server at {host}:{port} as user '{username}'...")
    
    # 1. Connect to default postgres DB and recreate database
    postgres_url = f"postgresql://{username}:{password}@{host}:{port}/postgres"
    engine = create_engine(postgres_url, isolation_level="AUTOCOMMIT")
    
    backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    
    with engine.connect() as conn:
        print(f"Terminating active sessions on database '{target_db}'...")
        try:
            conn.execute(text(f"""
                SELECT pg_terminate_backend(pg_stat_activity.pid)
                FROM pg_stat_activity
                WHERE pg_stat_activity.datname = '{target_db}'
                  AND pid <> pg_backend_pid()
            """))
        except Exception as e:
            print(f"Warning: could not terminate sessions: {e}")
            
        print(f"Dropping database '{target_db}' if it exists...")
        conn.execute(text(f'DROP DATABASE IF EXISTS "{target_db}"'))
        
        print(f"Creating database '{target_db}'...")
        conn.execute(text(f'CREATE DATABASE "{target_db}"'))
        print(f"Database '{target_db}' created successfully.")
        
    # 2. Run raw SQL files to construct schema, policies, and indexes
    print("Connecting to the new target database to run DDL scripts...")
    target_sync_url = f"postgresql://{username}:{password}@{host}:{port}/{target_db}"
    target_engine = create_engine(target_sync_url)
    
    sql_files = ["01_schema.sql", "02_rls_policies.sql", "03_indexes.sql"]
    sql_dir = os.path.abspath(os.path.join(backend_dir, "..", "SQL"))
    
    with target_engine.connect() as conn:
        # psycopg2 allows executing multiple statements in one execute call
        for sql_file in sql_files:
            file_path = os.path.join(sql_dir, sql_file)
            print(f"Executing SQL file: {sql_file}...")
            if not os.path.exists(file_path):
                print(f"Error: SQL file not found at {file_path}")
                sys.exit(1)
            with open(file_path, "r", encoding="utf-8") as f:
                content = f.read()
            # Execute raw SQL
            conn.execute(text(content))
        print("Schema, triggers, and indexes created successfully.")

    # 3. Stamp migrations to head in alembic_version table
    print("Stamping database migrations to head using Alembic...")
    try:
        subprocess.run(
            [sys.executable, "-m", "alembic", "stamp", "head"],
            cwd=backend_dir,
            check=True,
            shell=True
        )
        print("Alembic stamped database successfully.")
    except subprocess.CalledProcessError as e:
        print(f"Error stamping database: {e}")
        sys.exit(1)
        
    # 4. Run seed script
    print("Seeding database...")
    try:
        subprocess.run(
            [sys.executable, "scripts/seed.py"],
            cwd=backend_dir,
            check=True,
            shell=True
        )
        print("Seeding completed successfully.")
    except subprocess.CalledProcessError as e:
        print(f"Error running seeding script: {e}")
        sys.exit(1)

    print("\nDatabase setup and seeding completed successfully!")

if __name__ == "__main__":
    main()

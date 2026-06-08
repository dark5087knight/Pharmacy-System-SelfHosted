from sqlalchemy import create_engine, text

def create_db():
    # Connect to default postgres DB and use AUTOCOMMIT to avoid transaction blocks
    # which CREATE DATABASE does not allow.
    url = "postgresql://dark:writeline@192.168.0.11:5432/postgres"
    engine = create_engine(url, isolation_level="AUTOCOMMIT")
    with engine.connect() as conn:
        try:
            conn.execute(text('CREATE DATABASE "PharmacySH"'))
            print("Database 'PharmacySH' created successfully.")
        except Exception as e:
            if "already exists" in str(e):
                print("Database 'PharmacySH' already exists.")
            else:
                print(f"Error bootstraping database: {e}")

if __name__ == "__main__":
    create_db()

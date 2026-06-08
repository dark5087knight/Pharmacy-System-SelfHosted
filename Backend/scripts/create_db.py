from sqlalchemy import create_engine, text

def create_db():
    # Connect to default postgres DB and use AUTOCOMMIT to avoid transaction blocks
    # which CREATE DATABASE does not allow.
    url = "postgresql://pharmacy:PassWD@127.0.0.1:5432/postgres"
    engine = create_engine(url, isolation_level="AUTOCOMMIT")
    with engine.connect() as conn:
        try:
            conn.execute(text('CREATE DATABASE "pharmacy"'))
            print("Database 'pharmacy' created successfully.")
        except Exception as e:
            if "already exists" in str(e):
                print("Database 'pharmacy' already exists.")
            else:
                print(f"Error bootstraping database: {e}")

if __name__ == "__main__":
    create_db()

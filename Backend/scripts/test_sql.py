from sqlalchemy import create_engine, text
import os

SQL_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "SQL"))

def test_sql():
    # Connect directly using the raw engine
    url = "postgresql://pharmacy:PassWD@127.0.0.1:5432/pharmacy"
    engine = create_engine(url)
    
    for sql_file in ["01_schema.sql", "02_rls_policies.sql", "03_indexes.sql"]:
        filepath = os.path.join(SQL_DIR, sql_file)
        with open(filepath, "r", encoding="utf-8") as f:
            sql_content = f.read()

        with engine.begin() as conn:
            try:
                print(f"Executing {sql_file}...")
                conn.execute(text(sql_content))
                print(f"Successfully executed {sql_file}!")
            except Exception as e:
                print(f"FAILED EXECUTING {sql_file}")
                print(f"Error class: {e.__class__}")
                # Print only the first 5 lines of the error to avoid huge output
                err_lines = str(e).splitlines()
                print("Error detail:")
                for line in err_lines[:10]:
                    print(line)
                return

if __name__ == "__main__":
    test_sql()

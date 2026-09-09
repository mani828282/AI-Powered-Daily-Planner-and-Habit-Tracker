import sys
import os
sys.path.append(os.getcwd())
from database import Database  # type: ignore

def check_tables():
    try:
        tables = Database.execute_query("SHOW TABLES", fetch=True)
        print("Tables in database:")
        for t in tables:
            print(f"- {list(t.values())[0]}")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    check_tables()

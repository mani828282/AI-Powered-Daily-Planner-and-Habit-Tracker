import os
import mysql.connector
from urllib.parse import urlparse

def get_connection():
    # Attempt to get DATABASE_URL from environment (provided by DigitalOcean)
    db_url = os.getenv("DATABASE_URL")
    
    if db_url:
        print(f"Connecting using DATABASE_URL environment variable...")
        try:
            parsed = urlparse(db_url)
            return mysql.connector.connect(
                host=parsed.hostname,
                port=parsed.port or 3306,
                user=parsed.username,
                password=parsed.password,
                database=parsed.path.lstrip("/")
            )
        except Exception as e:
            print(f"Error parsing DATABASE_URL: {e}")
            return None
    else:
        # Fallback to local defaults if DATABASE_URL is missing
        print("DATABASE_URL NOT FOUND. Attempting local connection...")
        try:
            return mysql.connector.connect(
                host="localhost",
                port=3306,
                user="root",
                password="",
                database="ai_planner_db"
            )
        except Exception as e:
            print(f"Failed to connect to local database: {e}")
            return None

def inspect_database():
    conn = get_connection()
    if not conn:
        print("Could not establish database connection.")
        return

    try:
        cursor = conn.cursor(dictionary=True)
        
        # Get all tables
        cursor.execute("SHOW TABLES")
        tables_raw = cursor.fetchall()
        
        if not tables_raw:
            print("No tables found in the database.")
            return

        print("\n" + "="*50)
        print("DATABASE SCHEMA INSPECTION")
        print("="*50)

        for table_entry in tables_raw:
            table_name = list(table_entry.values())[0]
            print(f"\nTABLE: {table_name}")
            print("-" * (len(table_name) + 7))
            
            # Get columns for this table
            cursor.execute(f"DESCRIBE `{table_name}`")
            columns = cursor.fetchall()
            
            # Print header for columns
            print(f"{'Field':<25} | {'Type':<20} | {'Null':<5} | {'Key':<5} | {'Default':<10} | {'Extra'}")
            print("-" * 90)
            
            for col in columns:
                field = col['Field']
                col_type = col['Type']
                null = col['Null']
                key = col['Key']
                default = str(col['Default'])
                extra = col['Extra']
                print(f"{field:<25} | {col_type:<20} | {null:<5} | {key:<5} | {default:<10} | {extra}")
        
        print("\n" + "="*50)
        print("INSPECTION COMPLETE")
        print("="*50)

    except Exception as e:
        print(f"Error during inspection: {e}")
    finally:
        if 'cursor' in locals():
            cursor.close()
        if 'conn' in locals() and conn.is_connected():
            conn.close()

if __name__ == "__main__":
    inspect_database()

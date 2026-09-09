"""
Import the FULL phpMyAdmin dump (ai_planner_db.sql) into Aiven MySQL 8.4
Handles MariaDB -> MySQL 8 compatibility issues.
"""
import mysql.connector
import re
import sys
import os

# Aiven connection details (loaded from environment variables)
DB_HOST = os.environ.get("DB_HOST", "mysql-11a8ce02-maharabdulrehman5-e3c5.h.aivencloud.com")
DB_PORT = int(os.environ.get("DB_PORT", "18217"))
DB_USER = os.environ.get("DB_USER", "avnadmin")
DB_PASSWORD = os.environ.get("DB_PASSWORD", "")
DB_NAME = os.environ.get("DB_NAME", "defaultdb")

print("=" * 60)
print("  IMPORTING FULL DUMP TO AIVEN MySQL 8.4")
print("=" * 60)

# Connect with autocommit
try:
    conn = mysql.connector.connect(
        host=DB_HOST,
        port=DB_PORT,
        user=DB_USER,
        password=DB_PASSWORD,
        database=DB_NAME,
        ssl_disabled=False,
        connection_timeout=30,
        autocommit=True
    )
    cursor = conn.cursor()
    print("[OK] Connected to Aiven MySQL successfully!\n")
except Exception as e:
    print(f"[FAIL] Connection FAILED: {e}")
    sys.exit(1)

# Step 1: Drop ALL existing tables
print("--- Dropping existing tables ---")
cursor.execute("SET FOREIGN_KEY_CHECKS = 0")
cursor.execute("SHOW TABLES")
tables = cursor.fetchall()
for (table_name,) in tables:
    try:
        cursor.execute(f"DROP TABLE IF EXISTS `{table_name}`")
        print(f"  [DROPPED] {table_name}")
    except Exception as e:
        print(f"  [ERROR] dropping {table_name}: {e}")
cursor.execute("SET FOREIGN_KEY_CHECKS = 1")
print()

# Step 2: Read the SQL dump file
sql_file = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "ai_planner_db.sql")
if not os.path.exists(sql_file):
    print(f"[FAIL] SQL file not found: {sql_file}")
    sys.exit(1)
    
print(f"Reading SQL file: {sql_file}")
with open(sql_file, "r", encoding="utf-8") as f:
    sql_content = f.read()

# Step 3: Fix MariaDB -> MySQL 8 compatibility
# Remove CHECK constraints with json_valid (MariaDB-specific, MySQL 8 handles JSON differently)
sql_content = re.sub(r"\s*CHECK\s*\(json_valid\(`[^`]+`\)\)", "", sql_content)

# Replace MariaDB current_timestamp() with MySQL CURRENT_TIMESTAMP
sql_content = sql_content.replace("current_timestamp()", "CURRENT_TIMESTAMP")

# Remove comments
sql_content = re.sub(r'^--.*$', '', sql_content, flags=re.MULTILINE)

# Step 4: Extract and execute statements properly
# Use a simple semicolon split but handle multi-line statements
cursor.execute("SET FOREIGN_KEY_CHECKS = 0")
cursor.execute("SET SQL_MODE = 'NO_AUTO_VALUE_ON_ZERO'")
cursor.execute("SET SESSION sql_require_primary_key = 0")

# Split into statements
raw_statements = sql_content.split(';')

executed = 0
errors = 0

for raw_stmt in raw_statements:
    stmt = raw_stmt.strip()
    if not stmt:
        continue
    
    # Skip pure comment blocks
    if stmt.startswith('/*!') and stmt.endswith('*/'):
        try:
            cursor.execute(stmt + ';')
            executed += 1
        except:
            pass
        continue
    
    # Skip START TRANSACTION and COMMIT (we're in autocommit mode)
    upper = stmt.upper().strip()
    if upper in ('START TRANSACTION', 'COMMIT', ''):
        continue
    
    try:
        cursor.execute(stmt)
        executed += 1
        
        # Log important operations
        if 'CREATE TABLE' in upper:
            # Extract table name
            match = re.search(r'CREATE TABLE\s+`?(\w+)`?', stmt, re.IGNORECASE)
            tname = match.group(1) if match else "?"
            print(f"  [OK] CREATE TABLE {tname}")
        elif 'ALTER TABLE' in upper and 'ADD PRIMARY' in upper:
            match = re.search(r'ALTER TABLE\s+`?(\w+)`?', stmt, re.IGNORECASE)
            tname = match.group(1) if match else "?"
            print(f"  [OK] ADD INDEXES on {tname}")
        elif 'ALTER TABLE' in upper and 'AUTO_INCREMENT' in upper:
            match = re.search(r'ALTER TABLE\s+`?(\w+)`?', stmt, re.IGNORECASE)
            tname = match.group(1) if match else "?"
            print(f"  [OK] AUTO_INCREMENT on {tname}")
        elif 'ALTER TABLE' in upper and 'CONSTRAINT' in upper:
            match = re.search(r'ALTER TABLE\s+`?(\w+)`?', stmt, re.IGNORECASE)
            tname = match.group(1) if match else "?"
            print(f"  [OK] FOREIGN KEYS on {tname}")
        elif 'INSERT' in upper:
            print(f"  [OK] INSERT data")
            
    except mysql.connector.Error as e:
        err_msg = str(e)
        if "already exists" in err_msg or "Duplicate" in err_msg:
            pass  # Skip silently
        else:
            preview = stmt[:80].replace('\n', ' ').strip()
            print(f"  [ERR] {preview}")
            print(f"        {err_msg}")
            errors += 1

cursor.execute("SET FOREIGN_KEY_CHECKS = 1")

print(f"\n{'=' * 60}")
print(f"  Executed: {executed}, Errors: {errors}")
print(f"{'=' * 60}")

# Verify tables
cursor.execute("SHOW TABLES")
tables = cursor.fetchall()
print(f"\nTables in database ({len(tables)}):")
for (t,) in tables:
    try:
        cursor.execute(f"SELECT COUNT(*) FROM `{t}`")
        count = cursor.fetchone()[0]
        print(f"  [OK] {t} ({count} rows)")
    except:
        print(f"  [OK] {t}")

if len(tables) > 0:
    print(f"\n[SUCCESS] DATABASE IMPORT COMPLETE! {len(tables)} tables created.")
else:
    print(f"\n[FAIL] No tables were created. Check errors above.")

cursor.close()
conn.close()

"""
ONE-TIME Database Migration Script
Adds start_date, start_time, end_date to tasks table
Adds start_date, end_date to goals table

Run from the DigitalOcean App Platform console:
    python3 migrate.py
"""

import os
import sys
from urllib.parse import urlparse

print("=" * 60)
print("  HABIT TRACKER - DATABASE MIGRATION")
print("=" * 60)

# ---------------------------------------------------------------
# Read connection details — same logic as config.py
# DigitalOcean App Platform injects DATABASE_URL automatically
# ---------------------------------------------------------------
DB_HOST = "localhost"
DB_PORT = 3306
DB_USER = "root"
DB_PASSWORD = ""
DB_NAME = "ai_planner_db"

db_url = os.getenv("DATABASE_URL")
if db_url:
    print(f"  Found DATABASE_URL — parsing connection details...")
    try:
        parsed = urlparse(db_url)
        DB_HOST = parsed.hostname or DB_HOST
        DB_PORT = parsed.port or DB_PORT
        DB_USER = parsed.username or DB_USER
        DB_PASSWORD = parsed.password or DB_PASSWORD
        DB_NAME = parsed.path.lstrip("/") or DB_NAME
    except Exception as e:
        print(f"  Warning: Could not parse DATABASE_URL: {e}")
else:
    # Fall back to individual env vars
    print("  No DATABASE_URL found — checking individual DB_* env vars...")
    DB_HOST     = os.getenv("DB_HOST", DB_HOST)
    DB_PORT     = int(os.getenv("DB_PORT", DB_PORT))
    DB_USER     = os.getenv("DB_USER", DB_USER)
    DB_PASSWORD = os.getenv("DB_PASSWORD", DB_PASSWORD)
    DB_NAME     = os.getenv("DB_NAME", DB_NAME)

print(f"  Host:     {DB_HOST}")
print(f"  Port:     {DB_PORT}")
print(f"  User:     {DB_USER}")
print(f"  Database: {DB_NAME}")
print()

# ---------------------------------------------------------------
# Connect
# ---------------------------------------------------------------
try:
    import mysql.connector
    conn = mysql.connector.connect(
        host=DB_HOST,
        port=int(DB_PORT),
        user=DB_USER,
        password=DB_PASSWORD,
        database=DB_NAME,
        ssl_disabled=False
    )
    cursor = conn.cursor()
    print(f"✓ Connected successfully!\n")
except Exception as e:
    print(f"✗ Connection FAILED: {e}")
    print("\nEnvironment variables available (DB/DATABASE related):")
    for k, v in os.environ.items():
        if any(x in k.upper() for x in ["DB", "DATABASE", "MYSQL", "SQL"]):
            display = v[:40] + "..." if len(v) > 40 else v
            print(f"  {k} = {display}")
    sys.exit(1)

# ---------------------------------------------------------------
# Migration steps
# ---------------------------------------------------------------
steps = [
    (
        "Add tasks.start_date column",
        "ALTER TABLE tasks ADD COLUMN start_date DATE NULL AFTER due_date"
    ),
    (
        "Add tasks.start_time column",
        "ALTER TABLE tasks ADD COLUMN start_time TIME NULL AFTER start_date"
    ),
    (
        "Add tasks.end_date column",
        "ALTER TABLE tasks ADD COLUMN end_date DATE NULL AFTER start_time"
    ),
    (
        "Add goals.start_date column",
        "ALTER TABLE goals ADD COLUMN start_date DATE NULL AFTER target_date"
    ),
    (
        "Add goals.end_date column",
        "ALTER TABLE goals ADD COLUMN end_date DATE NULL AFTER start_date"
    ),
    (
        "Backfill tasks start_date and end_date from due_date",
        "UPDATE tasks SET start_date = COALESCE(due_date, CURDATE()), end_date = COALESCE(due_date, CURDATE()) WHERE start_date IS NULL"
    ),
    (
        "Backfill goals start_date and end_date",
        "UPDATE goals SET start_date = COALESCE(DATE(created_at), CURDATE()), end_date = COALESCE(target_date, DATE_ADD(CURDATE(), INTERVAL 30 DAY)) WHERE start_date IS NULL"
    ),
    (
        "Add index on tasks.start_date",
        "ALTER TABLE tasks ADD INDEX idx_start_date (start_date)"
    ),
    (
        "Add index on goals.start_date",
        "ALTER TABLE goals ADD INDEX idx_goal_start_date (start_date)"
    ),
]

print("Running migration steps...\n")

for name, query in steps:
    try:
        cursor.execute(query)
        conn.commit()
        print(f"  ✓ {name}")
    except mysql.connector.errors.DatabaseError as e:
        err_msg = str(e)
        if "Duplicate column name" in err_msg or "already exists" in err_msg or "Duplicate key name" in err_msg:
            print(f"  ⚠ SKIPPED (already done): {name}")
        else:
            print(f"  ✗ ERROR: {name}")
            print(f"    {err_msg}")

# ---------------------------------------------------------------
# Verification
# ---------------------------------------------------------------
print("\n" + "=" * 60)
print("VERIFICATION")
print("=" * 60)

cursor.execute("SELECT COUNT(*) FROM tasks WHERE start_date IS NULL OR end_date IS NULL")
tasks_nulls = cursor.fetchone()[0]
print(f"Tasks with NULL start/end date: {tasks_nulls}  {'✓ OK' if tasks_nulls == 0 else '✗ PROBLEM'}")

cursor.execute("SELECT COUNT(*) FROM goals WHERE start_date IS NULL OR end_date IS NULL")
goals_nulls = cursor.fetchone()[0]
print(f"Goals with NULL start/end date: {goals_nulls}  {'✓ OK' if goals_nulls == 0 else '✗ PROBLEM'}")

cursor.execute("DESCRIBE tasks")
columns = [row[0] for row in cursor.fetchall()]
print(f"tasks.start_date exists:  {'✓' if 'start_date' in columns else '✗'}")
print(f"tasks.start_time exists:  {'✓' if 'start_time' in columns else '✗'}")
print(f"tasks.end_date exists:    {'✓' if 'end_date' in columns else '✗'}")

cursor.execute("DESCRIBE goals")
columns = [row[0] for row in cursor.fetchall()]
print(f"goals.start_date exists:  {'✓' if 'start_date' in columns else '✗'}")
print(f"goals.end_date exists:    {'✓' if 'end_date' in columns else '✗'}")

all_ok = (
    tasks_nulls == 0 and goals_nulls == 0 and
    'start_date' in columns and 'end_date' in columns
)

if all_ok:
    print("\n✅ MIGRATION COMPLETE — Database is ready!")
else:
    print("\n⚠  Some steps need attention. Check errors above.")

cursor.close()
conn.close()

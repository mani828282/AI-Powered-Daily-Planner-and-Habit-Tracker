import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from database import Database

def dump_schema():
    try:
        tables = Database.execute_query("SHOW TABLES", fetch=True)
        if not tables:
            print("No tables found in the database.")
            return

        schema_output = []
        for table_dict in tables:
            # The dictionary key is the column name for the tables view, usually something like 'Tables_in_ai_planner_db'
            table_name = list(table_dict.values())[0]
            
            # Get the CREATE TABLE statement
            create_stmt_res = Database.execute_query(f"SHOW CREATE TABLE `{table_name}`", fetch=True)
            if create_stmt_res:
                create_stmt = create_stmt_res[0].get('Create Table', '')
                schema_output.append(f"-- Schema for {table_name}\n{create_stmt};\n")

        with open("schema_dump.sql", "w") as f:
            f.write("\n\n".join(schema_output))
            
        print("Schema dumped successfully to schema_dump.sql")
    except Exception as e:
        print(f"Error dumping schema: {e}")

if __name__ == "__main__":
    dump_schema()

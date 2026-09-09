import mysql.connector
from mysql.connector import pooling
from config import settings
from typing import Optional
import logging
import ssl

logger = logging.getLogger(__name__)

class Database:
    _connection_pool: Optional[pooling.MySQLConnectionPool] = None
    
    @classmethod
    def _get_ssl_config(cls):
        """Get SSL configuration for cloud MySQL connections"""
        if settings.DB_SSL:
            return {
                "ssl_disabled": False,
                "ssl_verify_cert": False,  # Most free providers use self-signed certs
            }
        return {"ssl_disabled": True}
    
    @classmethod
    def get_pool(cls):
        """Get or create connection pool"""
        if cls._connection_pool is None:
            try:
                # Use smaller pool for free tier (connection limits)
                pool_size = 3 if settings.DB_SSL else 10
                
                pool_config = {
                    "pool_name": "ai_planner_pool",
                    "pool_size": pool_size,
                    "pool_reset_session": True,
                    "host": settings.DB_HOST,
                    "port": settings.DB_PORT,
                    "user": settings.DB_USER,
                    "password": settings.DB_PASSWORD,
                    "database": settings.DB_NAME,
                    "charset": "utf8mb4",
                    "collation": "utf8mb4_unicode_ci",
                    "connection_timeout": 10,
                }
                
                # Add SSL config
                pool_config.update(cls._get_ssl_config())
                
                cls._connection_pool = pooling.MySQLConnectionPool(**pool_config)
                logger.info(f"Database pool created for: {settings.DB_USER}@{settings.DB_HOST}:{settings.DB_PORT}/{settings.DB_NAME} (SSL: {settings.DB_SSL})")
            except Exception as e:
                logger.error(f"Error creating connection pool: {e}")
                raise
        return cls._connection_pool
    
    @classmethod
    def get_connection(cls):
        """Get a connection from the pool"""
        try:
            pool = cls.get_pool()
            return pool.get_connection()
        except Exception as e:
            logger.error(f"Error getting database connection: {e}")
            raise
    
    @classmethod
    def execute_query(cls, query: str, params: tuple = None, fetch: bool = False):
        """Execute a query and optionally fetch results"""
        connection = None
        cursor = None
        def convert_timedelta(obj):
            from datetime import timedelta, time
            if isinstance(obj, dict):
                for k, v in obj.items():
                    if isinstance(v, timedelta):
                        total_seconds = int(v.total_seconds())
                        obj[k] = time(hour=(total_seconds // 3600) % 24, minute=(total_seconds % 3600) // 60)
            elif isinstance(obj, list):
                for item in obj:
                    convert_timedelta(item)
            return obj

        try:
            connection = cls.get_connection()
            cursor = connection.cursor(dictionary=True)
            cursor.execute(query, params or ())
            
            if fetch:
                result = cursor.fetchall()
                return convert_timedelta(result)
            else:
                connection.commit()
                return cursor.lastrowid
        except Exception as e:
            if connection:
                connection.rollback()
            logger.error(f"Database error: {e}")
            raise
        finally:
            if cursor:
                cursor.close()
            if connection:
                connection.close()
    
    @classmethod
    def execute_many(cls, query: str, data: list):
        """Execute many queries at once"""
        connection = None
        cursor = None
        try:
            connection = cls.get_connection()
            cursor = connection.cursor()
            cursor.executemany(query, data)
            connection.commit()
            return cursor.rowcount
        except Exception as e:
            if connection:
                connection.rollback()
            logger.error(f"Database error: {e}")
            raise
        finally:
            if cursor:
                cursor.close()
            if connection:
                connection.close()

    @classmethod
    def execute_script(cls, script: str):
        """Execute a SQL script containing multiple statements"""
        connection = None
        cursor = None
        errors = []
        executed_count = 0
        try:
            connection = cls.get_connection()
            cursor = connection.cursor()
            
            # Remove comments to avoid issues with splitting
            import re
            # Remove single line comments starting with --
            script = re.sub(r'^--.*', '', script, flags=re.MULTILINE)
            # Remove multi-line comments but preserve executable comments /*! ... */
            # Match /* followed by anything NOT starting with !
            script = re.sub(r'/\*(?!!).*?\*/', '', script, flags=re.DOTALL)
            
            # Split by semicolon
            statements = script.split(';')
            
            for statement in statements:
                if statement.strip():
                    try:
                        cursor.execute(statement)
                        executed_count += 1
                    except Exception as stmt_err:
                        logger.error(f"Error executing statement: {stmt_err}")
                        errors.append(str(stmt_err))
                        
            connection.commit()
            return {"success": len(errors) == 0, "executed": executed_count, "errors": errors}
        except Exception as e:
            if connection:
                connection.rollback()
            logger.error(f"Script execution error: {e}")
            raise
        finally:
            if cursor:
                cursor.close()
            if connection:
                connection.close()

# Helper function for getting database connection
def get_db():
    """Dependency for getting database connection"""
    connection = Database.get_connection()
    try:
        yield connection
    finally:
        connection.close()

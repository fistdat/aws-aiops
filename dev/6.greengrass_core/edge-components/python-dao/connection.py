"""
Database Connection Manager with connection pooling and thread-safety
"""
import sqlite3
import logging
from contextlib import contextmanager
from typing import Optional, List, Dict
from threading import Lock
from pathlib import Path

logger = logging.getLogger(__name__)


class DatabaseManager:
    """
    Singleton database connection manager
    Provides thread-safe connection pooling for SQLite database
    """

    _instance: Optional['DatabaseManager'] = None
    _lock = Lock()

    def __new__(cls, db_path: str = "/var/greengrass/database/greengrass.db"):
        if cls._instance is None:
            with cls._lock:
                if cls._instance is None:
                    cls._instance = super().__new__(cls)
                    cls._instance._initialize(db_path)
        return cls._instance

    def _initialize(self, db_path: str):
        """Initialize database manager"""
        self.db_path = db_path
        self._ensure_database_exists()
        self._verify_database()
        logger.info(f"DatabaseManager initialized: {db_path}")

    def _ensure_database_exists(self):
        """Ensure database file and directory exist"""
        db_file = Path(self.db_path)
        db_file.parent.mkdir(parents=True, exist_ok=True)

        if not db_file.exists():
            logger.warning(f"Database file not found, will be created: {self.db_path}")

    def _verify_database(self):
        """Verify database exists and is accessible"""
        try:
            with self.get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("SELECT COUNT(*) as count FROM sqlite_master WHERE type='table'")
                result = cursor.fetchone()
                table_count = result[0] if result else 0
                logger.info(f"Database verified: {table_count} tables found")

                if table_count == 0:
                    logger.warning("Database has no tables - schema may need to be applied")

        except Exception as e:
            logger.error(f"Database verification failed: {e}")
            raise

    @contextmanager
    def get_connection(self):
        """
        Context manager for database connections
        Automatically handles commit/rollback and close

        Usage:
            with db.get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("SELECT ...")
        """
        conn = sqlite3.connect(
            self.db_path,
            check_same_thread=False,
            timeout=30.0
        )
        conn.row_factory = sqlite3.Row  # Return rows as dictionaries

        try:
            yield conn
            conn.commit()
        except Exception as e:
            conn.rollback()
            logger.error(f"Database transaction failed: {e}")
            raise
        finally:
            conn.close()

    def execute_query(self, query: str, params: tuple = ()) -> List[Dict]:
        """
        Execute a read query and return results as list of dicts

        Args:
            query: SQL SELECT query
            params: Query parameters (tuple)

        Returns:
            List of dictionaries representing rows
        """
        with self.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(query, params)
            return [dict(row) for row in cursor.fetchall()]

    def execute_update(self, query: str, params: tuple = ()) -> int:
        """
        Execute an insert/update/delete query

        Args:
            query: SQL INSERT/UPDATE/DELETE query
            params: Query parameters (tuple)

        Returns:
            Number of affected rows
        """
        with self.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(query, params)
            return cursor.rowcount

    def get_schema_version(self) -> str:
        """Get current database schema version"""
        try:
            result = self.execute_query("SELECT schema_version FROM _metadata LIMIT 1")
            return result[0]['schema_version'] if result else "unknown"
        except Exception as e:
            logger.warning(f"Could not retrieve schema version: {e}")
            return "unknown"

    def health_check(self) -> Dict[str, any]:
        """
        Perform database health check

        Returns:
            Dictionary with health status
        """
        try:
            schema_version = self.get_schema_version()
            table_count = self.execute_query(
                "SELECT COUNT(*) as count FROM sqlite_master WHERE type='table'"
            )[0]['count']

            camera_count = self.execute_query("SELECT COUNT(*) as count FROM cameras")[0]['count']
            incident_count = self.execute_query("SELECT COUNT(*) as count FROM incidents")[0]['count']
            pending_sync = self.execute_query(
                "SELECT COUNT(*) as count FROM incidents WHERE synced_to_cloud = 0"
            )[0]['count']

            return {
                "status": "healthy",
                "db_path": self.db_path,
                "schema_version": schema_version,
                "table_count": table_count,
                "cameras": camera_count,
                "incidents": incident_count,
                "pending_sync": pending_sync
            }
        except Exception as e:
            logger.error(f"Health check failed: {e}")
            return {
                "status": "unhealthy",
                "error": str(e)
            }

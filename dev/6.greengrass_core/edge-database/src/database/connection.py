"""
Database Connection Manager with connection pooling
Implements singleton pattern for thread-safe SQLite access
"""
import sqlite3
import logging
from contextlib import contextmanager
from typing import Optional, List, Dict
from threading import Lock

logger = logging.getLogger(__name__)


class DatabaseManager:
    """Singleton database connection manager for SQLite"""

    _instance: Optional['DatabaseManager'] = None
    _lock = Lock()

    def __new__(cls, db_path: str = "/var/greengrass/database/greengrass.db"):
        """
        Singleton pattern ensures only one instance exists
        Thread-safe implementation using Lock
        """
        if cls._instance is None:
            with cls._lock:
                if cls._instance is None:
                    cls._instance = super().__new__(cls)
                    cls._instance._initialize(db_path)
        return cls._instance

    def _initialize(self, db_path: str):
        """Initialize database manager"""
        self.db_path = db_path
        self._verify_database()
        logger.info(f"DatabaseManager initialized with {db_path}")

    def _verify_database(self):
        """Verify database exists and is accessible"""
        try:
            with self.get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute(
                    "SELECT COUNT(*) FROM sqlite_master WHERE type='table'"
                )
                table_count = cursor.fetchone()[0]
                logger.info(f"Database verified: {table_count} tables found")

                if table_count == 0:
                    raise RuntimeError(
                        "Database has no tables. Run schema initialization first."
                    )
        except sqlite3.Error as e:
            logger.error(f"Database verification failed: {e}")
            raise RuntimeError(f"Database not accessible: {e}")

    @contextmanager
    def get_connection(self):
        """
        Context manager for database connections
        Automatically handles commit/rollback and close

        Usage:
            with db.get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("SELECT * FROM cameras")
        """
        conn = sqlite3.connect(
            self.db_path,
            check_same_thread=False,
            timeout=30.0
        )
        conn.row_factory = sqlite3.Row  # Return rows as dictionaries

        # Enable WAL mode for better concurrent access
        conn.execute("PRAGMA journal_mode=WAL")
        conn.execute("PRAGMA foreign_keys=ON")

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
            params: Query parameters (use ? placeholders)

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
            query: SQL DML query
            params: Query parameters

        Returns:
            Number of rows affected
        """
        with self.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(query, params)
            return cursor.rowcount

    def health_check(self) -> Dict[str, any]:
        """
        Perform database health check

        Returns:
            Dictionary with health status information
        """
        try:
            with self.get_connection() as conn:
                cursor = conn.cursor()

                # Check database integrity
                cursor.execute("PRAGMA integrity_check")
                integrity = cursor.fetchone()[0]

                # Get table counts
                cursor.execute("""
                    SELECT
                        (SELECT COUNT(*) FROM cameras) as cameras,
                        (SELECT COUNT(*) FROM incidents) as incidents,
                        (SELECT COUNT(*) FROM message_queue WHERE status='pending') as pending_messages
                """)
                counts = dict(cursor.fetchone())

                return {
                    "status": "healthy" if integrity == "ok" else "unhealthy",
                    "integrity": integrity,
                    "database_path": self.db_path,
                    **counts
                }
        except Exception as e:
            logger.error(f"Health check failed: {e}")
            return {
                "status": "unhealthy",
                "error": str(e)
            }

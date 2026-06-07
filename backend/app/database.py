import psycopg2
from app.config import settings

def get_db_connection():
    """Establish and return a new connection to the PostgreSQL database."""
    return psycopg2.connect(
        host=settings.DB_HOST,
        database=settings.DB_NAME,
        user=settings.DB_USER,
        password=settings.DB_PASSWORD,
        port=settings.DB_PORT,
        sslmode="require"
    )

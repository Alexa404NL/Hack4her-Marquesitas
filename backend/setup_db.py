import os
import io
import pandas as pd
import psycopg2
from dotenv import load_dotenv

# Load configuration
load_dotenv()

DB_HOST = os.getenv("DB_HOST")
DB_USER = os.getenv("DB_USER")
DB_PASSWORD = os.getenv("DB_PASSWORD")
DB_NAME = os.getenv("DB_NAME")
DB_PORT = os.getenv("DB_PORT")

def get_db_connection():
    return psycopg2.connect(
        host=DB_HOST,
        database=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD,
        port=DB_PORT,
        sslmode="require"
    )

def create_tables(conn):
    cur = conn.cursor()
    print("Creating tables and indexes if they do not exist...")
    
    # Create orders table
    cur.execute("""
    CREATE TABLE IF NOT EXISTS orders (
        id_pedido VARCHAR(255) PRIMARY KEY,
        customer_id VARCHAR(255),
        pais VARCHAR(100),
        id_businessunit INTEGER,
        business_unit VARCHAR(100),
        cedis VARCHAR(100),
        fecha_pedido VARCHAR(100),
        fecha_entrega VARCHAR(100),
        status_final VARCHAR(100),
        valor_pedido NUMERIC,
        SubTotal NUMERIC,
        Total NUMERIC
    );
    """)
    
    # Create order_details table
    cur.execute("""
    CREATE TABLE IF NOT EXISTS order_details (
        id_linea VARCHAR(255) PRIMARY KEY,
        id_pedido VARCHAR(255),
        sku_solicitado BIGINT,
        nombre_sku_solicitado VARCHAR(255),
        Quantity INTEGER,
        Status VARCHAR(100)
    );
    """)
    
    # Create indexes for performance
    print("Verifying database indexes...")
    cur.execute("CREATE INDEX IF NOT EXISTS idx_orders_customer_id ON orders(customer_id);")
    cur.execute("CREATE INDEX IF NOT EXISTS idx_orders_status_final ON orders(status_final);")
    cur.execute("CREATE INDEX IF NOT EXISTS idx_order_details_id_pedido ON order_details(id_pedido);")
    cur.execute("CREATE INDEX IF NOT EXISTS idx_order_details_sku_solicitado ON order_details(sku_solicitado);")
    
    conn.commit()
    cur.close()
    print("[OK] Tables and indexes verified successfully.")

def copy_dataframe_to_db(conn, df, table_name, columns):
    """Bulk copies a pandas dataframe to PostgreSQL using copy_expert."""
    output = io.StringIO()
    # Write using standard comma separation, letting pandas handle all quote escaping
    df.to_csv(output, sep=',', header=False, index=False, na_rep='\\N')
    output.seek(0)
    
    cur = conn.cursor()
    cols_str = ', '.join(columns)
    # Use standard PostgreSQL CSV parser which correctly parses double quotes
    copy_sql = f"COPY {table_name} ({cols_str}) FROM STDIN WITH CSV NULL AS '\\N'"
    
    try:
        print(f"Loading {len(df):,} rows into {table_name}...")
        cur.copy_expert(copy_sql, output)
        conn.commit()
        print(f"[OK] Successfully loaded {table_name}.")
    except Exception as e:
        conn.rollback()
        print(f"[Error] Failed to load {table_name}: {e}")
        raise e
    finally:
        cur.close()

def import_orders(conn):
    print("\n--- IMPORTING ORDERS ---")
    df = pd.read_csv('bd/Orders.csv', dtype={
        'id_pedido': str,
        'customer_id': str,
        'pais': str,
        'id_businessunit': 'Int64',
        'business_unit': str,
        'cedis': str,
        'fecha_pedido': str,
        'fecha_entrega': str,
        'status_final': str,
        'valor_pedido': float,
        'SubTotal': float,
        'Total': float
    })
    
    # Clean string columns and replace standard 'nan' string with actual None (NULL in SQL)
    for col in ['id_pedido', 'customer_id', 'pais', 'business_unit', 'cedis', 'fecha_pedido', 'fecha_entrega', 'status_final']:
        df[col] = df[col].astype(str).str.strip().replace({'nan': None, 'None': None})
    
    # Drop rows missing primary key and drop duplicates
    df = df.dropna(subset=['id_pedido'])
    df = df.drop_duplicates(subset=['id_pedido'])
    
    cols = [
        'id_pedido', 'customer_id', 'pais', 'id_businessunit', 'business_unit', 
        'cedis', 'fecha_pedido', 'fecha_entrega', 'status_final', 
        'valor_pedido', 'SubTotal', 'Total'
    ]
    df = df[cols]
    
    # Clear existing data before reloading
    cur = conn.cursor()
    cur.execute("TRUNCATE TABLE orders CASCADE;")
    conn.commit()
    cur.close()
    
    copy_dataframe_to_db(conn, df, 'orders', cols)

def import_order_details(conn):
    print("\n--- IMPORTING ORDER DETAILS ---")
    df = pd.read_csv('bd/OrderDetails.csv', dtype={
        'id_linea': str,
        'id_pedido': str,
        'sku_solicitado': float, # read as float to handle numeric conversions properly
        'nombre_sku_solicitado': str,
        'Quantity': 'Int64',
        'Status': str
    })
    
    # Clean IDs
    df['id_linea'] = df['id_linea'].astype(str).str.strip()
    df['id_pedido'] = df['id_pedido'].astype(str).str.strip()
    
    # Handle NaN in key columns
    df = df.dropna(subset=['id_linea', 'id_pedido', 'sku_solicitado'])
    
    # Cast sku_solicitado to big integer
    df['sku_solicitado'] = df['sku_solicitado'].astype(int)
    
    # Clean other strings
    df['nombre_sku_solicitado'] = df['nombre_sku_solicitado'].astype(str).str.strip().replace({'nan': None, 'None': None})
    df['Status'] = df['Status'].astype(str).str.strip().replace({'nan': None, 'None': None})
    
    # Drop duplicates on primary key
    df = df.drop_duplicates(subset=['id_linea'])
    
    cols = ['id_linea', 'id_pedido', 'sku_solicitado', 'nombre_sku_solicitado', 'Quantity', 'Status']
    df = df[cols]
    
    # Clear existing data before reloading
    cur = conn.cursor()
    cur.execute("TRUNCATE TABLE order_details CASCADE;")
    conn.commit()
    cur.close()
    
    copy_dataframe_to_db(conn, df, 'order_details', cols)

def main():
    print("=== DATABASE SETUP AND DATA SEEDING PIPELINE ===")
    try:
        conn = get_db_connection()
        print("[OK] Connected to PostgreSQL database.")
        
        # 1. Create tables and indexes
        create_tables(conn)
        
        # 2. Import Orders
        import_orders(conn)
        
        # 3. Import Order Details
        import_order_details(conn)
        
        conn.close()
        print("\n=== DATABASE SETUP COMPLETED SUCCESSFULY ===")
    except Exception as e:
        print(f"\n[FATAL ERROR] Setup pipeline failed: {e}")

if __name__ == "__main__":
    main()

import os
import json
import urllib.request
import urllib.error
import time
import pandas as pd
import psycopg2
from psycopg2.extras import execute_values
from dotenv import load_dotenv

# Load configuration from .env file
load_dotenv()

# Configuration Settings
DB_HOST = os.getenv("DB_HOST")
DB_USER = os.getenv("DB_USER")
DB_PASSWORD = os.getenv("DB_PASSWORD")
DB_NAME = os.getenv("DB_NAME")
DB_PORT = os.getenv("DB_PORT")
API_KEY = os.getenv("API_GEMINI")

MODEL_NAME = "models/gemini-embedding-2" # Best latest model
DIMENSIONALITY = 768
BATCH_SIZE = 100  # API batch limit is exactly 100 requests
MAX_RETRIES = 5   # Maximum retries on API failure
DELAY_BETWEEN_BATCHES = 12.0 # Delay in seconds to keep rate under 5 RPM (safely below 15 RPM limit)

def get_db_connection():
    """Establish and return a database connection with SSL enabled."""
    return psycopg2.connect(
        host=DB_HOST,
        database=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD,
        port=DB_PORT,
        sslmode="require",
        sslrootcert="ca.pem"
    )

def test_connections():
    """Verify essential connection configurations before starting."""
    if not API_KEY:
        raise ValueError("API_GEMINI is missing in the .env file.")
    if not all([DB_HOST, DB_USER, DB_PASSWORD, DB_NAME, DB_PORT]):
        raise ValueError("One or more DB connection environment variables are missing in .env.")
    
    # Test DB Connection
    try:
        conn = get_db_connection()
        conn.close()
        print("[OK] Database connection test passed.")
    except Exception as e:
        raise ConnectionError(f"Failed to connect to database: {e}")

def load_and_clean_data(conn):
    """Load CSVs, join them, clean data, and filter out already processed SKUs."""
    print("Loading Orders.csv...")
    orders = pd.read_csv('Orders.csv', usecols=['id_pedido', 'business_unit'])
    
    print("Loading OrderDetails.csv...")
    details = pd.read_csv('OrderDetails.csv', usecols=['id_pedido', 'sku_solicitado', 'nombre_sku_solicitado'])
    
    print("Cleaning and merging datasets...")
    # Drop rows missing crucial values
    details = details.dropna(subset=['sku_solicitado', 'nombre_sku_solicitado'])
    orders = orders.dropna(subset=['id_pedido', 'business_unit'])
    
    # Convert id_pedido to string to avoid float precision errors during merge
    details['id_pedido'] = details['id_pedido'].astype(str).str.strip()
    orders['id_pedido'] = orders['id_pedido'].astype(str).str.strip()
    
    # Inner join on id_pedido
    merged = pd.merge(details, orders, on='id_pedido', how='inner')
    
    # Clean string spaces
    merged['nombre_sku_solicitado'] = merged['nombre_sku_solicitado'].astype(str).str.strip()
    merged['business_unit'] = merged['business_unit'].astype(str).str.strip()
    
    # Parse sku_solicitado as float (handles scientific notation), then cast to BIGINT range integers
    merged['sku_solicitado'] = pd.to_numeric(merged['sku_solicitado'], errors='coerce')
    merged = merged.dropna(subset=['sku_solicitado'])
    merged['sku_solicitado'] = merged['sku_solicitado'].astype(int)
    
    # Filter out empty names or categories
    merged = merged[merged['nombre_sku_solicitado'] != ""]
    merged = merged[merged['business_unit'] != ""]
    
    # Group by sku_solicitado to get the unique catalog
    catalog = merged.groupby('sku_solicitado').first().reset_index()
    catalog = catalog[['sku_solicitado', 'nombre_sku_solicitado', 'business_unit']]
    
    # Check already processed SKUs in the database
    cur = conn.cursor()
    cur.execute("SELECT sku_solicitado FROM catalogo_vectorizado")
    existing_skus = set(row[0] for row in cur.fetchall())
    cur.close()
    
    initial_count = len(catalog)
    # Filter out existing SKUs
    catalog = catalog[~catalog['sku_solicitado'].isin(existing_skus)]
    
    # Create the text context that will be embedded
    catalog['context_text'] = catalog.apply(
        lambda row: f"Producto: {row['nombre_sku_solicitado']}, Categoría: {row['business_unit']}", axis=1
    )
    
    print(f"[OK] Data loaded and cleaned.")
    print(f"  - Total unique SKUs in CSV: {initial_count}")
    print(f"  - Already processed in DB:  {len(existing_skus)}")
    print(f"  - Remaining to process:     {len(catalog)}")
    return catalog

def get_embeddings_batch(texts):
    """Retrieve embeddings for a batch of texts from Gemini API with retry logic."""
    url = f"https://generativelanguage.googleapis.com/v1beta/{MODEL_NAME}:batchEmbedContents?key={API_KEY}"
    
    # Construct batch request body
    requests_list = []
    for text in texts:
        requests_list.append({
            "model": MODEL_NAME,
            "content": {
                "parts": [{"text": text}]
            },
            "outputDimensionality": DIMENSIONALITY
        })
    
    payload = {"requests": requests_list}
    headers = {"Content-Type": "application/json"}
    
    for attempt in range(1, MAX_RETRIES + 1):
        try:
            req = urllib.request.Request(
                url, 
                data=json.dumps(payload).encode("utf-8"), 
                headers=headers, 
                method="POST"
            )
            with urllib.request.urlopen(req, timeout=45) as response:
                res_data = json.loads(response.read().decode("utf-8"))
                embeddings = [e["values"] for e in res_data["embeddings"]]
                return embeddings
        except urllib.error.HTTPError as e:
            try:
                error_body = e.read().decode("utf-8")
            except:
                error_body = str(e)
                
            if e.code == 429:
                sleep_time = 65  # Sleep 65 seconds to clear sliding rate limit window
                print(f"  [Rate Limit] Hit API rate limit (429) on attempt {attempt}/{MAX_RETRIES}. Sleeping for {sleep_time}s to reset limit window...")
                time.sleep(sleep_time)
            else:
                print(f"  [Warning] HTTP Error {e.code} on attempt {attempt}/{MAX_RETRIES}: {error_body}")
                if attempt < MAX_RETRIES:
                    time.sleep(2 ** attempt)
                else:
                    raise e
        except Exception as e:
            print(f"  [Warning] API call failed on attempt {attempt}/{MAX_RETRIES}: {e}")
            if attempt < MAX_RETRIES:
                time.sleep(2 ** attempt)
            else:
                raise e
    
    raise RuntimeError("Failed to fetch embeddings from Gemini API after maximum retries.")

def save_to_database(conn, catalog_chunk, embeddings):
    """Upsert a batch of records and embeddings into the PostgreSQL database."""
    cur = conn.cursor()
    
    # Prepare data for bulk insert/upsert
    upsert_data = []
    for (_, row), emb in zip(catalog_chunk.iterrows(), embeddings):
        emb_str = f"[{','.join(map(str, emb))}]"
        upsert_data.append((
            int(row['sku_solicitado']),
            row['nombre_sku_solicitado'],
            row['business_unit'],
            emb_str
        ))
        
    query = """
    INSERT INTO catalogo_vectorizado (sku_solicitado, nombre_sku_solicitado, business_unit, embedding)
    VALUES %s
    ON CONFLICT (sku_solicitado) DO UPDATE SET
        nombre_sku_solicitado = EXCLUDED.nombre_sku_solicitado,
        business_unit = EXCLUDED.business_unit,
        embedding = EXCLUDED.embedding;
    """
    
    try:
        execute_values(cur, query, upsert_data)
        conn.commit()
    except Exception as e:
        conn.rollback()
        raise e
    finally:
        cur.close()

def main():
    print("=== CATALOG VECTORIZATION PIPELINE STARTED ===")
    start_time = time.time()
    
    # 1. Test connections
    test_connections()
    
    # 2. Get database connection
    db_conn = get_db_connection()
    
    try:
        # 3. Load, clean and filter CSVs
        catalog = load_and_clean_data(db_conn)
        
        total_records = len(catalog)
        if total_records == 0:
            print("[OK] No remaining records to process. All SKUs are already vectorized in the DB!")
            return
            
        inserted_count = 0
        total_batches = (total_records - 1) // BATCH_SIZE + 1
        
        for i in range(0, total_records, BATCH_SIZE):
            batch_df = catalog.iloc[i : i + BATCH_SIZE]
            texts = batch_df['context_text'].tolist()
            
            current_batch = i // BATCH_SIZE + 1
            print(f"Processing batch {current_batch} / {total_batches} ({len(texts)} items)...")
            
            # Get embeddings
            embeddings = get_embeddings_batch(texts)
            
            # Save to DB
            save_to_database(db_conn, batch_df, embeddings)
            
            inserted_count += len(texts)
            print(f"  -> Successfully vectorized and saved {inserted_count}/{total_records} remaining items.")
            
            # Respect rate limits with a sleep between API calls if not the last batch
            if current_batch < total_batches:
                time.sleep(DELAY_BETWEEN_BATCHES)
                
    finally:
        db_conn.close()
        
    end_time = time.time()
    duration = end_time - start_time
    print("\n=== PIPELINE SUCCESSFUL ===")
    print(f"Total processed and saved products: {inserted_count}")
    print(f"Total time elapsed: {duration:.2f} seconds")

if __name__ == "__main__":
    main()

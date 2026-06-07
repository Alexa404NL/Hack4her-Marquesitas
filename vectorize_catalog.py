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

MODEL_NAME = "models/gemini-embedding-2"
DIMENSIONALITY = 768
BATCH_SIZE = 100  # API batch limit is exactly 100 requests
MAX_RETRIES = 5
DELAY_BETWEEN_BATCHES = 12.0  # ~5 RPM to stay well under 15 RPM limit

def get_db_connection():
    return psycopg2.connect(
        host=DB_HOST, database=DB_NAME, user=DB_USER,
        password=DB_PASSWORD, port=DB_PORT,
        sslmode="require", sslrootcert="ca.pem"
    )

def test_connections():
    if not API_KEY:
        raise ValueError("API_GEMINI is missing in the .env file.")
    if not all([DB_HOST, DB_USER, DB_PASSWORD, DB_NAME, DB_PORT]):
        raise ValueError("One or more DB connection environment variables are missing.")
    conn = get_db_connection()
    conn.close()
    print("[OK] Database connection test passed.")

def load_and_clean_data(conn):
    print("Loading Orders.csv...")
    orders = pd.read_csv('Orders.csv', usecols=['id_pedido', 'business_unit'])
    print("Loading OrderDetails.csv...")
    details = pd.read_csv('OrderDetails.csv', usecols=['id_pedido', 'sku_solicitado', 'nombre_sku_solicitado'])
    print("Cleaning and merging datasets...")
    details = details.dropna(subset=['sku_solicitado', 'nombre_sku_solicitado'])
    orders = orders.dropna(subset=['id_pedido', 'business_unit'])
    details['id_pedido'] = details['id_pedido'].astype(str).str.strip()
    orders['id_pedido'] = orders['id_pedido'].astype(str).str.strip()
    merged = pd.merge(details, orders, on='id_pedido', how='inner')
    merged['nombre_sku_solicitado'] = merged['nombre_sku_solicitado'].astype(str).str.strip()
    merged['business_unit'] = merged['business_unit'].astype(str).str.strip()
    merged['sku_solicitado'] = pd.to_numeric(merged['sku_solicitado'], errors='coerce')
    merged = merged.dropna(subset=['sku_solicitado'])
    merged['sku_solicitado'] = merged['sku_solicitado'].astype(int)
    merged = merged[merged['nombre_sku_solicitado'] != ""]
    merged = merged[merged['business_unit'] != ""]
    catalog = merged.groupby('sku_solicitado').first().reset_index()
    catalog = catalog[['sku_solicitado', 'nombre_sku_solicitado', 'business_unit']]
    # Skip already-processed SKUs
    cur = conn.cursor()
    cur.execute("SELECT sku_solicitado FROM catalogo_vectorizado")
    existing_skus = set(row[0] for row in cur.fetchall())
    cur.close()
    initial_count = len(catalog)
    catalog = catalog[~catalog['sku_solicitado'].isin(existing_skus)]
    catalog['context_text'] = catalog.apply(
        lambda row: f"Producto: {row['nombre_sku_solicitado']}, Categoria: {row['business_unit']}", axis=1
    )
    print(f"[OK] Data loaded.")
    print(f"  - Total unique SKUs:      {initial_count}")
    print(f"  - Already in DB:          {len(existing_skus)}")
    print(f"  - Remaining to process:   {len(catalog)}")
    return catalog

def get_embeddings_batch(texts):
    url = f"https://generativelanguage.googleapis.com/v1beta/{MODEL_NAME}:batchEmbedContents?key={API_KEY}"
    requests_list = [
        {"model": MODEL_NAME, "content": {"parts": [{"text": t}]}, "outputDimensionality": DIMENSIONALITY}
        for t in texts
    ]
    payload = {"requests": requests_list}
    headers = {"Content-Type": "application/json"}
    for attempt in range(1, MAX_RETRIES + 1):
        try:
            req = urllib.request.Request(url, data=json.dumps(payload).encode("utf-8"), headers=headers, method="POST")
            with urllib.request.urlopen(req, timeout=45) as response:
                res_data = json.loads(response.read().decode("utf-8"))
                return [e["values"] for e in res_data["embeddings"]]
        except urllib.error.HTTPError as e:
            try:
                body = e.read().decode("utf-8")
            except:
                body = str(e)
            if e.code == 429:
                sleep_time = 65
                print(f"  [429 Rate Limit] attempt {attempt}/{MAX_RETRIES}. Sleeping {sleep_time}s...")
                time.sleep(sleep_time)
            else:
                print(f"  [HTTP {e.code}] attempt {attempt}/{MAX_RETRIES}: {body}")
                if attempt < MAX_RETRIES:
                    time.sleep(2 ** attempt)
                else:
                    raise
        except Exception as e:
            print(f"  [Error] attempt {attempt}/{MAX_RETRIES}: {e}")
            if attempt < MAX_RETRIES:
                time.sleep(2 ** attempt)
            else:
                raise
    raise RuntimeError("Max retries exceeded.")

def save_to_database(conn, batch_df, embeddings):
    cur = conn.cursor()
    upsert_data = []
    for (_, row), emb in zip(batch_df.iterrows(), embeddings):
        emb_str = f"[{','.join(map(str, emb))}]"
        upsert_data.append((int(row['sku_solicitado']), row['nombre_sku_solicitado'], row['business_unit'], emb_str))
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
        raise
    finally:
        cur.close()

def main():
    print("=== CATALOG VECTORIZATION PIPELINE ===")
    start = time.time()
    test_connections()
    db_conn = get_db_connection()
    try:
        catalog = load_and_clean_data(db_conn)
        total = len(catalog)
        if total == 0:
            print("[OK] All SKUs already vectorized!")
            return
        done = 0
        total_batches = (total - 1) // BATCH_SIZE + 1
        for i in range(0, total, BATCH_SIZE):
            batch_df = catalog.iloc[i : i + BATCH_SIZE]
            texts = batch_df['context_text'].tolist()
            batch_n = i // BATCH_SIZE + 1
            print(f"Batch {batch_n}/{total_batches} ({len(texts)} items)...")
            embeddings = get_embeddings_batch(texts)
            save_to_database(db_conn, batch_df, embeddings)
            done += len(texts)
            print(f"  -> {done}/{total} saved.")
            if batch_n < total_batches:
                time.sleep(DELAY_BETWEEN_BATCHES)
    finally:
        db_conn.close()
    print(f"\n=== DONE === {done} products vectorized in {time.time()-start:.1f}s")

if __name__ == "__main__":
    main()

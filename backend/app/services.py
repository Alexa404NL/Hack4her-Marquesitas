import numpy as np
import psycopg2
from typing import List, Dict, Any, Tuple
from app.database import get_db_connection

def map_product_details(sku: int, name: str, business_unit: str) -> Dict[str, Any]:
    """Map database product to a mock asset picture and price for Flutter UI."""
    name_lower = name.lower()
    picture = "assets/images/pedido.png"
    price_val = 25.0
    
    # Semantic keyword matching for assets and typical prices
    if any(keyword in name_lower for keyword in ["coca", "cola", "refresco", "sprite", "fanta", "soda"]):
        picture = "assets/images/coca.jpg" if "coca" in name_lower else "assets/images/refrescos.png"
        price_val = 35.0 if any(kw in name_lower for kw in ["botella", "pet", "personal"]) else 120.0
    elif "ciel" in name_lower or "agua purificada" in name_lower:
        picture = "assets/images/ciel.png"
        price_val = 15.0 if any(kw in name_lower for kw in ["1.00 l", "600 ml"]) else 45.0
    elif "agua" in name_lower:
        picture = "assets/images/agua.png"
        price_val = 12.0
    elif "topo" in name_lower or "mineral" in name_lower:
        picture = "assets/images/topo.png" if "topo" in name_lower else "assets/images/mineral.png"
        price_val = 25.0 if "botella" in name_lower else 150.0
    elif any(keyword in name_lower for keyword in ["jugo", "frut", "leche saborizada", "toni"]):
        picture = "assets/images/fruta.png"
        price_val = 20.0
    else:
        # Deterministic price based on SKU to keep it consistent
        price_val = 15.0 + (sku % 85)
        
    return {
        "sku": sku,
        "title": name.strip(),
        "picture": picture,
        "price": f"${price_val:.2f}"
    }

def get_customer_history(conn, customer_id: str, limit: int = 10) -> List[Dict[str, Any]]:
    """Retrieve top purchased products for a customer with average quantities."""
    cur = conn.cursor()
    query = """
        SELECT 
            od.sku_solicitado,
            od.nombre_sku_solicitado,
            o.business_unit,
            COUNT(o.id_pedido) as order_count,
            ROUND(AVG(od.Quantity)) as avg_quantity
        FROM orders o
        JOIN order_details od ON o.id_pedido = od.id_pedido
        WHERE o.customer_id = %s AND o.status_final = 'Entregado'
        GROUP BY od.sku_solicitado, od.nombre_sku_solicitado, o.business_unit
        ORDER BY order_count DESC, od.sku_solicitado ASC
        LIMIT %s;
    """
    cur.execute(query, (customer_id, limit))
    rows = cur.fetchall()
    cur.close()
    
    history = []
    for r in rows:
        sku, name, b_unit, count, avg_qty = r
        details = map_product_details(sku, name, b_unit)
        details["quantity"] = int(avg_qty) if avg_qty else 1
        history.append(details)
        
    return history

def get_recently_bought_skus(conn, customer_id: str, limit_orders: int = 10) -> List[int]:
    """Retrieve all unique SKUs purchased recently by the customer."""
    cur = conn.cursor()
    query = """
        SELECT DISTINCT od.sku_solicitado
        FROM orders o
        JOIN order_details od ON o.id_pedido = od.id_pedido
        WHERE o.customer_id = %s AND o.status_final = 'Entregado'
        LIMIT 50;
    """
    cur.execute(query, (customer_id,))
    rows = cur.fetchall()
    cur.close()
    return [row[0] for row in rows]

def get_embeddings_by_skus(conn, skus: List[int]) -> List[Tuple[int, List[float]]]:
    """Retrieve embeddings for a list of SKUs from the vectorized catalog."""
    if not skus:
        return []
    
    cur = conn.cursor()
    # Construct parameterized IN clause
    format_strings = ','.join(['%s'] * len(skus))
    query = f"""
        SELECT sku_solicitado, embedding 
        FROM catalogo_vectorizado 
        WHERE sku_solicitado IN ({format_strings});
    """
    cur.execute(query, tuple(skus))
    rows = cur.fetchall()
    cur.close()
    
    # Parse vector string format '[0.1, 0.2, ...]' back to a float list
    embeddings = []
    for r in rows:
        sku, emb_str = r
        # Clean embedding string if it has brackets
        if isinstance(emb_str, str):
            emb_str = emb_str.strip('[]')
            emb_list = [float(x) for x in emb_str.split(',')]
        else:
            emb_list = list(emb_str) # Already list if psycopg2 parses it
        embeddings.append((sku, emb_list))
        
    return embeddings

def get_vector_suggestions(conn, centroid: List[float], exclude_skus: List[int], limit: int = 5) -> List[Dict[str, Any]]:
    """Retrieve semantically compatible products from catalog vector using pgvector."""
    cur = conn.cursor()
    
    centroid_str = f"[{','.join(map(str, centroid))}]"
    
    # If there are SKUs to exclude, add the NOT IN clause
    if exclude_skus:
        format_strings = ','.join(['%s'] * len(exclude_skus))
        query = f"""
            SELECT sku_solicitado, nombre_sku_solicitado, business_unit,
                   1 - (embedding <=> %s::vector) AS similitud
            FROM catalogo_vectorizado
            WHERE sku_solicitado NOT IN ({format_strings})
            ORDER BY embedding <=> %s::vector ASC
            LIMIT %s;
        """
        params = (centroid_str, *exclude_skus, centroid_str, limit)
    else:
        query = """
            SELECT sku_solicitado, nombre_sku_solicitado, business_unit,
                   1 - (embedding <=> %s::vector) AS similitud
            FROM catalogo_vectorizado
            ORDER BY embedding <=> %s::vector ASC
            LIMIT %s;
        """
        params = (centroid_str, centroid_str, limit)
        
    cur.execute(query, params)
    rows = cur.fetchall()
    cur.close()
    
    suggestions = []
    for r in rows:
        sku, name, b_unit, similarity = r
        details = map_product_details(sku, name, b_unit)
        suggestions.append(details)
        
    return suggestions

def generate_pedido_inteligente(customer_id: str, current_cart_skus: List[int] = []) -> Dict[str, Any]:
    """
    Main business logic pipeline:
    1. Retrieve history of completed orders for the customer.
    2. Extract top products to build the dynamic profile.
    3. Calculate the centroid vector of top 3 products or current cart items.
    4. Query pgvector similarity excluding recently purchased products.
    """
    conn = get_db_connection()
    try:
        # 1. Recuperación de Contexto (Motor de Historial)
        history = get_customer_history(conn, customer_id, limit=10)
        
        # Determine recently bought SKUs to exclude from recommendations
        recently_bought = get_recently_bought_skus(conn, customer_id)
        
        # 2. Búsqueda de Similitudes (RAG con pgvector)
        # Find top 3 favorite products from history
        favorite_skus = [item["sku"] for item in history[:3]]
        
        # If the user has current cart items, we also factor them in
        source_skus = favorite_skus
        if not source_skus and current_cart_skus:
            source_skus = current_cart_skus[:3]
            
        # Get embeddings to calculate centroid
        embeddings_data = get_embeddings_by_skus(conn, source_skus)
        
        centroid = None
        if embeddings_data:
            embeddings_list = [emb for _, emb in embeddings_data]
            centroid = np.mean(embeddings_list, axis=0).tolist()
            
        # Fallback centroid: If no history/cart embeddings found, get centroid of the top 3 overall products in catalogo_vectorizado
        if centroid is None:
            cur = conn.cursor()
            cur.execute("SELECT embedding FROM catalogo_vectorizado LIMIT 3;")
            rows = cur.fetchall()
            cur.close()
            if rows:
                embs = []
                for r in rows:
                    emb_str = r[0].strip('[]') if isinstance(r[0], str) else r[0]
                    embs.append([float(x) for x in emb_str.split(',')] if isinstance(emb_str, str) else list(emb_str))
                centroid = np.mean(embs, axis=0).tolist()
            else:
                # Absolute fallback: Zero vector
                centroid = [0.0] * 768
                
        # Exclude currently selected cart items as well
        exclusion_list = list(set(recently_bought + current_cart_skus))
        
        # Perform similarity search
        suggestions = get_vector_suggestions(conn, centroid, exclusion_list, limit=5)
        
        # If customer has no history, let's load a few popular products as fallback pedido_sugerido
        if not history:
            cur = conn.cursor()
            cur.execute("""
                SELECT sku_solicitado, nombre_sku_solicitado, business_unit, COUNT(*) as cnt
                FROM order_details od
                JOIN orders o ON od.id_pedido = o.id_pedido
                GROUP BY sku_solicitado, nombre_sku_solicitado, business_unit
                ORDER BY cnt DESC
                LIMIT 5;
            """)
            fallback_rows = cur.fetchall()
            cur.close()
            for r in fallback_rows:
                sku, name, b_unit, _ = r
                item = map_product_details(sku, name, b_unit)
                item["quantity"] = 1
                history.append(item)
                
        return {
            "customer_id": customer_id,
            "pedido_sugerido": history,
            "sugerencias": suggestions
        }
    finally:
        conn.close()

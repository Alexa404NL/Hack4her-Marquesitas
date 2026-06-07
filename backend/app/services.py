import re
import unicodedata
import uuid
from datetime import datetime, timezone

import numpy as np
import psycopg2
from pydantic import BaseModel
from typing import List, Dict, Any, Optional, Tuple
from langchain_openai import ChatOpenAI
from app.config import settings
from app.database import get_db_connection
from app.models import CartItemIn

_DEDUPE_NOISE_WORDS = {"sabor", "original", "presentacion"}


def _canonical_title(title: str) -> str:
    """
    Canonicalizes a product title for duplicate detection: strips accents,
    punctuation/hyphen/spacing differences, and marketing noise words, so
    "Coca - Cola Sin Azúcar" and "Coca-Cola Sin Azúcar" collapse to the same
    key while "Coca-Cola" vs "Coca-Cola Zero" stay distinct.

    Tested cosine similarity on embeddings as a dedupe signal first — it
    doesn't separate cleanly ("Coca-Cola" vs "Coca-Cola Sabor Original" =
    0.925 vs "Coca-Cola" vs "Coca-Cola Zero" = 0.907, genuinely-different
    products land too close to genuinely-same ones). Text canonicalization
    is the more reliable signal for "is this the same catalog item".
    """
    text = unicodedata.normalize("NFKD", title).encode("ascii", "ignore").decode().lower()
    text = re.sub(r"[^a-z0-9\s]", " ", text)
    words = [w for w in text.split() if w not in _DEDUPE_NOISE_WORDS]
    return " ".join(words)


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
    """Retrieve semantically compatible products from catalog vector using pgvector.

    The catalog has many rows sharing the exact same `nombre_sku_solicitado`
    (different package sizes/SKUs of the same product line, often clustered
    tightly together by similarity), and since map_product_details derives
    title from that name, they render as visually identical recommendation
    cards — cosmetic name variants ("Coca - Cola Sin Azúcar" vs "Coca-Cola
    Sabor Original") make exact-string matching miss duplicates too. We
    over-fetch candidates and dedupe by canonical_title (see
    _canonical_title) so the user never sees the same product twice in one
    suggestion set. The multiplier is generous (12x): probing this customer's
    centroid showed only 3 distinct titles in the nearest 20 rows but 18 in
    the nearest 60 — same-name SKUs cluster together in similarity order.
    """
    cur = conn.cursor()

    centroid_str = f"[{','.join(map(str, centroid))}]"
    fetch_limit = limit * 12

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
        params = (centroid_str, *exclude_skus, centroid_str, fetch_limit)
    else:
        query = """
            SELECT sku_solicitado, nombre_sku_solicitado, business_unit,
                   1 - (embedding <=> %s::vector) AS similitud
            FROM catalogo_vectorizado
            ORDER BY embedding <=> %s::vector ASC
            LIMIT %s;
        """
        params = (centroid_str, centroid_str, fetch_limit)

    cur.execute(query, params)
    rows = cur.fetchall()
    cur.close()

    suggestions = []
    seen = set()
    for r in rows:
        sku, name, b_unit, similarity = r
        details = map_product_details(sku, name, b_unit)
        # Price is NOT part of the key: map_product_details often falls back to
        # a sku-derived mock price (15 + sku % 85), so identical catalog items
        # under different SKUs can show different "prices" — title is the real
        # identity signal here, price is cosmetic noise.
        dedupe_key = _canonical_title(details["title"])
        if dedupe_key in seen:
            continue
        seen.add(dedupe_key)
        suggestions.append(details)
        if len(suggestions) >= limit:
            break

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


def save_order(customer_id: str, items: List[CartItemIn]) -> Dict[str, Any]:
    """
    Persist a confirmed cart as a new order.

    Writes into the same `orders` / `order_details` tables the historical
    dataset uses (status_final='Entregado'), so generate_pedido_inteligente
    picks this order up as part of the customer's history on the very next
    request — no extra plumbing needed for the recommendation engine.
    """
    if not items:
        raise ValueError("Cannot save an empty order")

    id_pedido = f"APP-{uuid.uuid4().hex[:16].upper()}"
    now = datetime.now(timezone.utc).isoformat()
    total = round(sum(_parse_price(item.price) * item.quantity for item in items), 2)

    conn = get_db_connection()
    try:
        cur = conn.cursor()
        cur.execute(
            """
            INSERT INTO orders (
                id_pedido, customer_id, pais, id_businessunit, business_unit,
                cedis, fecha_pedido, fecha_entrega, status_final,
                valor_pedido, SubTotal, Total
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s);
            """,
            (
                id_pedido, customer_id, None, None, "App Movil",
                None, now, now, "Entregado",
                total, total, total,
            ),
        )

        for index, item in enumerate(items):
            id_linea = f"{id_pedido}-{index}"
            cur.execute(
                """
                INSERT INTO order_details (
                    id_linea, id_pedido, sku_solicitado, nombre_sku_solicitado,
                    Quantity, Status
                ) VALUES (%s, %s, %s, %s, %s, %s);
                """,
                (id_linea, id_pedido, item.sku, item.title, item.quantity, "Entregado"),
            )

        conn.commit()
        cur.close()
    finally:
        conn.close()

    return {"status": "ok", "id_pedido": id_pedido, "total": total}


def _parse_price(price: str) -> float:
    """Parses the Flutter '$120.00'-style price string into a float."""
    return float(price.replace("$", "").replace(",", "").strip() or 0)


def save_rl_feedback(state: List[float], action: int, reward: float, customer_id: str | None = None) -> None:
    """
    Persist one recommendation-rating experience into `rl_experiences`.

    Kept intentionally lightweight (plain INSERT, no Stable-Baselines3 model
    load) so the request path stays fast — the nightly offline trainer
    (rl_agent.py train_offline) is what turns these rows into a better model.
    """
    if not (0 <= action <= 4):
        raise ValueError("action must be between 0 and 4")
    if not (-1.0 <= reward <= 1.0):
        raise ValueError("reward must be between -1.0 and 1.0")

    conn = get_db_connection()
    try:
        cur = conn.cursor()
        cur.execute(
            """INSERT INTO rl_experiences (state, action, reward, customer_id)
               VALUES (%s, %s, %s, %s)""",
            (state, action, reward, customer_id),
        )
        conn.commit()
        cur.close()
    finally:
        conn.close()


# ---------------------------------------------------------------------------
# Auto-order agent (LangChain + Gemini)
# ---------------------------------------------------------------------------

class _AutoOrderLLMItem(BaseModel):
    title: str
    suggested_quantity: int
    reason: str


class _AutoOrderLLMPlan(BaseModel):
    items: List[_AutoOrderLLMItem]
    summary: str


_AUTO_ORDER_PROMPT = """Eres un agente de re-pedido para un cliente recurrente de una tienda B2B de bebidas.

Productos que el cliente ha comprado antes (nombre: cantidad promedio por pedido):
{history_lines}

Productos que el cliente ya tiene en su carrito actual (nombre: cantidad):
{cart_lines}

Tarea: arma una propuesta de pedido para hoy. Para cada producto que aparezca en
cualquiera de las dos listas de arriba (sin repetir), decide la cantidad que
recomendarías para este pedido y da una razón breve en español (máx. 20 palabras),
por ejemplo si conviene subir la cantidad respecto a su promedio o a lo que ya
tiene en el carrito, y por qué. No inventes productos que no estén en las listas.
Termina con un resumen de tu estrategia general (máx. 2 frases, en español).
"""


def _build_auto_order_candidates(
    history: List[Dict[str, Any]], current_cart: List[CartItemIn]
) -> Dict[str, Dict[str, Any]]:
    """Maps canonical_title -> candidate details, merging purchase history with the live cart.

    Keying by _canonical_title (the same dedupe signal used for recommendation
    cards) means SKU variants of one product line collapse into a single
    candidate — so the agent reasons about "Coca-Cola", not three near-duplicate
    SKU rows of it.
    """
    candidates: Dict[str, Dict[str, Any]] = {}
    for item in history:
        key = _canonical_title(item["title"])
        candidates[key] = {
            "sku": item["sku"],
            "title": item["title"],
            "picture": item["picture"],
            "price": item["price"],
            "history_quantity": item["quantity"],
            "cart_quantity": 0,
        }
    for item in current_cart:
        key = _canonical_title(item.title)
        if key in candidates:
            candidates[key]["cart_quantity"] = item.quantity
        else:
            candidates[key] = {
                "sku": item.sku,
                "title": item.title,
                "picture": map_product_details(item.sku, item.title, "")["picture"],
                "price": item.price,
                "history_quantity": 0,
                "cart_quantity": item.quantity,
            }
    return candidates


def generate_auto_order(customer_id: str, current_cart: List[CartItemIn]) -> Dict[str, Any]:
    """
    Runs a LangChain + Gemini agent that proposes a re-order plan from purchase
    history and the live cart, with per-item suggested quantities and reasons.

    The LLM only ever picks from a server-built candidate list (history + cart
    items, deduped by canonical title) — it cannot hallucinate SKUs/prices,
    those stay authoritative from the DB. `change_type` is derived by comparing
    the agent's suggested_quantity against what's already in the cart, which is
    exactly the "proposed change" the UI highlights for accept/reject.
    """
    conn = get_db_connection()
    try:
        history = get_customer_history(conn, customer_id, limit=10)
    finally:
        conn.close()

    if not history and not current_cart:
        raise ValueError("No hay historial de compras ni carrito para generar un pedido automático")

    candidates = _build_auto_order_candidates(history, current_cart)

    history_lines = "\n".join(
        f"- {c['title']}: {c['history_quantity']}"
        for c in candidates.values() if c["history_quantity"] > 0
    ) or "(sin historial de compras)"
    cart_lines = "\n".join(
        f"- {c['title']}: {c['cart_quantity']}"
        for c in candidates.values() if c["cart_quantity"] > 0
    ) or "(carrito vacío)"

    llm = ChatOpenAI(
        model="openai/gpt-4o-mini",
        api_key=settings.API_KEY,
        base_url="https://openrouter.ai/api/v1",
        temperature=0.3,
    )
    structured_llm = llm.with_structured_output(_AutoOrderLLMPlan)
    prompt = _AUTO_ORDER_PROMPT.format(history_lines=history_lines, cart_lines=cart_lines)

    try:
        plan = structured_llm.invoke(prompt)
    except Exception as exc:
        raise RuntimeError(f"El agente de pedido automático no está disponible: {exc}") from exc

    items = []
    for llm_item in plan.items:
        candidate = candidates.get(_canonical_title(llm_item.title))
        if candidate is None:
            continue  # ignore anything outside the candidate list (no hallucinated SKUs)

        cart_qty = candidate["cart_quantity"]
        suggested_qty = max(1, llm_item.suggested_quantity)
        if cart_qty == 0:
            change_type = "new"
        elif suggested_qty > cart_qty:
            change_type = "increased"
        elif suggested_qty < cart_qty:
            change_type = "decreased"
        else:
            change_type = "same"

        items.append({
            "sku": candidate["sku"],
            "title": candidate["title"],
            "picture": candidate["picture"],
            "price": candidate["price"],
            "cart_quantity": cart_qty,
            "suggested_quantity": suggested_qty,
            "change_type": change_type,
            "reason": llm_item.reason.strip(),
        })

    return {"customer_id": customer_id, "items": items, "summary": plan.summary.strip()}


def save_agent_feedback(customer_id: Optional[str], rating: int, comment: Optional[str] = None) -> None:
    """
    Persists "how useful was the agent" feedback for the auto-order feature.

    Creates `agent_feedback` on first use (CREATE TABLE IF NOT EXISTS is cheap
    and idempotent) instead of requiring a separate manual migration step,
    matching how lightweight the rest of this feedback plumbing is.
    """
    if not (1 <= rating <= 5):
        raise ValueError("rating must be between 1 and 5")
    
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        cur.execute("""
                CREATE TABLE IF NOT EXISTS agent_feedback (
                id BIGSERIAL PRIMARY KEY,
                created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                customer_id TEXT,
                rating SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
                comment TEXT
            );
            """
        )
        cur.execute(
            "INSERT INTO agent_feedback (customer_id, rating, comment) VALUES (%s, %s, %s)",
            (customer_id, rating, comment),
        )
        conn.commit()
        cur.close()
    finally:
        conn.close()
    
    

# ──────────────────────────────────────────────────────────────────────────────
# Goals (Metas) service functions
# ──────────────────────────────────────────────────────────────────────────────

def get_all_goals() -> List[Dict[str, Any]]:
    """Fetch all goals from the database (no customer_id filter — hackathon scope)."""
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        cur.execute("""
            SELECT id, title, goal_type, target_value, target_unit,
                   is_autosuggest, is_completed, current_progress,
                   created_at, completed_at
            FROM goals
            ORDER BY created_at DESC
            LIMIT 50;
        """)
        rows = cur.fetchall()
        cur.close()
        goals = []
        for r in rows:
            (gid, title, goal_type, target_value, target_unit,
             is_autosuggest, is_completed, current_progress,
             created_at, completed_at) = r
            goals.append({
                "id": gid,
                "title": title,
                "goal_type": goal_type,
                "target_value": float(target_value),
                "target_unit": target_unit,
                "is_autosuggest": bool(is_autosuggest),
                "is_completed": bool(is_completed),
                "current_progress": float(current_progress),
                "created_at": created_at.isoformat() if created_at else "",
                "completed_at": completed_at.isoformat() if completed_at else None,
            })
        return goals
    finally:
        conn.close()


def create_goal(title: str, goal_type: str, target_value: float,
                target_unit: str, is_autosuggest: bool = False) -> Dict[str, Any]:
    """Insert a new goal row and return its id."""
    # Use the VARCHAR customer_id string that exists in the orders table
    # so the FK constraint is satisfied. For this hackathon, all goals
    # are attributed to this single test account.
    PLACEHOLDER_CUSTOMER_ID = '5.183610e+17'
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        cur.execute(
            """
            INSERT INTO goals
                (customer_id, title, goal_type, target_value, target_unit, is_autosuggest)
            VALUES (%s, %s, %s, %s, %s, %s)
            RETURNING id;
            """,
            (PLACEHOLDER_CUSTOMER_ID, title, goal_type, target_value, target_unit, is_autosuggest),
        )
        new_id = cur.fetchone()[0]
        conn.commit()
        cur.close()
        return {"status": "ok", "id": new_id}
    finally:
        conn.close()


def get_suggested_goals() -> List[Dict[str, Any]]:
    """
    Generate smart goal suggestions from aggregate purchase patterns across ALL orders.
    Falls back gracefully to hardcoded sensible defaults if the DB is unavailable.
    """
    HARDCODED_SUGGESTIONS = [
        {
            "title": "Alcanzar $5,000 en compras este mes",
            "goal_type": "spending",
            "target_value": 5000.0,
            "target_unit": "pesos",
            "reason": "Las tiendas similares gastan en promedio $4,800 al mes — ¡estás muy cerca!",
        },
        {
            "title": "Hacer 3 pedidos esta semana",
            "goal_type": "frequency",
            "target_value": 3.0,
            "target_unit": "orders",
            "reason": "Los revendedores más exitosos hacen pedidos frecuentes para mantener inventario fresco.",
        },
        {
            "title": "Comprar 50 unidades de bebidas",
            "goal_type": "volume",
            "target_value": 50.0,
            "target_unit": "units",
            "reason": "Las bebidas son la categoría más vendida — abastécete mejor.",
        },
        {
            "title": "Probar 5 productos nuevos",
            "goal_type": "exploration",
            "target_value": 5.0,
            "target_unit": "products",
            "reason": "Diversificar tu catálogo puede aumentar tus ventas hasta un 20%.",
        },
        {
            "title": "Mantener pedidos consistentes por 4 semanas",
            "goal_type": "habit",
            "target_value": 4.0,
            "target_unit": "weeks",
            "reason": "La consistencia en pedidos te garantiza mejor disponibilidad de producto.",
        },
    ]

    try:
        conn = get_db_connection()
        cur = conn.cursor()

        # Average monthly spend across all delivered orders
        cur.execute("""
            SELECT AVG(monthly_total)
            FROM (
                SELECT DATE_TRUNC('month', fecha_pedido) AS month,
                       SUM(Total) AS monthly_total
                FROM orders
                WHERE status_final = 'Entregado'
                GROUP BY month
            ) AS monthly;
        """)
        avg_spend_row = cur.fetchone()
        avg_spend = float(avg_spend_row[0]) if avg_spend_row and avg_spend_row[0] else 4000.0

        # Average weekly order frequency
        cur.execute("""
            SELECT COUNT(*) / NULLIF(
                EXTRACT(WEEK FROM MAX(fecha_pedido)) - EXTRACT(WEEK FROM MIN(fecha_pedido)), 0
            )
            FROM orders WHERE status_final = 'Entregado';
        """)
        freq_row = cur.fetchone()
        avg_freq = float(freq_row[0]) if freq_row and freq_row[0] else 2.0

        cur.close()
        conn.close()

        suggested_spend = round(avg_spend * 1.15 / 500) * 500  # bump 15%, round to nearest 500
        suggested_orders = max(3, round(avg_freq) + 1)

        return [
            {
                "title": f"Alcanzar ${suggested_spend:,.0f} en compras este mes",
                "goal_type": "spending",
                "target_value": float(suggested_spend),
                "target_unit": "pesos",
                "reason": f"El promedio mensual de la red es ${avg_spend:,.0f} — sube un 15% y supéralos.",
            },
            {
                "title": f"Hacer {suggested_orders} pedidos esta semana",
                "goal_type": "frequency",
                "target_value": float(suggested_orders),
                "target_unit": "orders",
                "reason": "Los revendedores de alto rendimiento hacen pedidos frecuentes para stock fresco.",
            },
            {
                "title": "Comprar 50 unidades de bebidas",
                "goal_type": "volume",
                "target_value": 50.0,
                "target_unit": "units",
                "reason": "Las bebidas lideran ventas — asegúrate de tener suficiente inventario.",
            },
            {
                "title": "Descubrir 5 productos nuevos",
                "goal_type": "exploration",
                "target_value": 5.0,
                "target_unit": "products",
                "reason": "Diversificar tu catálogo puede aumentar tus ventas hasta un 20%.",
            },
            {
                "title": "Mantener pedidos 4 semanas seguidas",
                "goal_type": "habit",
                "target_value": 4.0,
                "target_unit": "weeks",
                "reason": "La consistencia garantiza mejor disponibilidad de producto.",
            },
        ]
    except Exception:
        import traceback
        traceback.print_exc()
        return HARDCODED_SUGGESTIONS

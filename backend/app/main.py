from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from app.models import (
    PedidoInteligenteRequest,
    PedidoInteligenteResponse,
    SaveOrderRequest,
    SaveOrderResponse,
    RlFeedbackRequest,
    RlFeedbackResponse,
    AutoOrderRequest,
    AutoOrderResponse,
    AgentFeedbackRequest,
    AgentFeedbackResponse,
    GoalCreate,
    GoalListResponse,
    GoalCreateResponse,
    SuggestedGoalsResponse,
)
from app.services import (
    generate_pedido_inteligente,
    save_order,
    save_rl_feedback,
    generate_auto_order,
    save_agent_feedback,
    get_all_goals,
    create_goal,
    get_suggested_goals,
)

app = FastAPI(
    title="Hack4Her Marquesitas Backend",
    description="Business logic backend for Smart Orders and recommendations using pgvector RAG.",
    version="1.0.0"
)

# Enable CORS for Flutter app integration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
def read_root():
    return {"message": "Welcome to the Hack4Her Marquesitas API!"}

@app.get("/login")
def login():
    # Helper endpoint requested by Flutter's login.dart.
    # Returns a valid test customer ID that has historical orders in the database.
    return {
        "status": "success",
        "customer_id": "5.183610e+17"
    }

@app.post("/api/pedido-inteligente", response_model=PedidoInteligenteResponse)
def post_pedido_inteligente(payload: PedidoInteligenteRequest):
    try:
        data = generate_pedido_inteligente(
            customer_id=payload.customer_id,
            current_cart_skus=payload.current_cart_skus or []
        )
        return data
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Internal Server Error: {str(e)}")

@app.post("/api/orders", response_model=SaveOrderResponse)
def post_save_order(payload: SaveOrderRequest):
    try:
        return save_order(customer_id=payload.customer_id, items=payload.items)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Internal Server Error: {str(e)}")

@app.post("/api/rl/feedback", response_model=RlFeedbackResponse)
def post_rl_feedback(payload: RlFeedbackRequest):
    try:
        save_rl_feedback(payload.state, payload.action, payload.reward, payload.customer_id)
        return {"status": "ok"}
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Internal Server Error: {str(e)}")

@app.post("/api/pedido-automatico", response_model=AutoOrderResponse)
def post_auto_order(payload: AutoOrderRequest):
    try:
        return generate_auto_order(customer_id=payload.customer_id, current_cart=payload.current_cart or [])
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except RuntimeError as e:
        raise HTTPException(status_code=502, detail=str(e))

# ── Goals (Metas) endpoints ───────────────────────────────────────────────────

@app.get("/api/goals", response_model=GoalListResponse)
def list_goals():
    """Return all stored goals (hackathon: no customer_id filter)."""
    try:
        goals = get_all_goals()
        return {"goals": goals}
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Internal Server Error: {str(e)}")

@app.post("/api/agent-feedback", response_model=AgentFeedbackResponse)
def post_agent_feedback(payload: AgentFeedbackRequest):
    try:
        save_agent_feedback(payload.customer_id, payload.rating, payload.comment)
        return {"status": "ok"}
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.post("/api/goals", response_model=GoalCreateResponse)
def post_create_goal(payload: GoalCreate):
    """Create a new goal."""
    try:
        result = create_goal(
            title=payload.title,
            goal_type=payload.goal_type,
            target_value=payload.target_value,
            target_unit=payload.target_unit,
            is_autosuggest=payload.is_autosuggest or False,
        )
        return result
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Internal Server Error: {str(e)}")


@app.get("/api/goals/suggestions", response_model=SuggestedGoalsResponse)
def list_suggested_goals():
    """Return AI-suggested goals derived from aggregate purchase patterns."""
    try:
        suggestions = get_suggested_goals()
        return {"suggestions": suggestions}
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Internal Server Error: {str(e)}")

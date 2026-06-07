from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from app.models import PedidoInteligenteRequest, PedidoInteligenteResponse
from app.services import generate_pedido_inteligente

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

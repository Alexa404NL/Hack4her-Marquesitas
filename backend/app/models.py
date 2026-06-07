from pydantic import BaseModel
from typing import List, Optional

class PedidoInteligenteRequest(BaseModel):
    customer_id: str
    current_cart_skus: Optional[List[int]] = []

class ProductItem(BaseModel):
    sku: int
    title: str
    picture: str
    price: str
    quantity: Optional[int] = None

class PedidoInteligenteResponse(BaseModel):
    customer_id: str
    pedido_sugerido: List[ProductItem]
    sugerencias: List[ProductItem]


class CartItemIn(BaseModel):
    sku: int
    title: str
    quantity: int
    price: str


class SaveOrderRequest(BaseModel):
    customer_id: str
    items: List[CartItemIn]


class SaveOrderResponse(BaseModel):
    status: str
    id_pedido: str
    total: float


class RlFeedbackRequest(BaseModel):
    state: List[float]
    action: int
    reward: float
    customer_id: Optional[str] = None


class RlFeedbackResponse(BaseModel):
    status: str


# ──────────────────────────────────────────────────────────────────────────────
# Goals (Metas) models
# ──────────────────────────────────────────────────────────────────────────────

class GoalCreate(BaseModel):
    title: str
    goal_type: str  # 'spending' | 'volume' | 'frequency' | 'exploration' | 'habit'
    target_value: float
    target_unit: str  # 'pesos' | 'units' | 'orders' | 'products' | 'weeks'
    is_autosuggest: Optional[bool] = False


class GoalOut(BaseModel):
    id: int
    title: str
    goal_type: str
    target_value: float
    target_unit: str
    is_autosuggest: bool
    is_completed: bool
    current_progress: float
    created_at: str
    completed_at: Optional[str] = None


class SuggestedGoal(BaseModel):
    title: str
    goal_type: str
    target_value: float
    target_unit: str
    reason: str


class GoalListResponse(BaseModel):
    goals: List[GoalOut]


class SuggestedGoalsResponse(BaseModel):
    suggestions: List[SuggestedGoal]


class GoalCreateResponse(BaseModel):
    status: str
    id: int

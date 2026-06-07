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


class AutoOrderRequest(BaseModel):
    customer_id: str
    current_cart: Optional[List[CartItemIn]] = []


class AutoOrderItem(BaseModel):
    sku: int
    title: str
    picture: str
    price: str
    cart_quantity: int
    suggested_quantity: int
    change_type: str  # "new" | "increased" | "decreased" | "same"
    reason: str


class AutoOrderResponse(BaseModel):
    customer_id: str
    items: List[AutoOrderItem]
    summary: str


class AgentFeedbackRequest(BaseModel):
    customer_id: Optional[str] = None
    rating: int
    comment: Optional[str] = None


class AgentFeedbackResponse(BaseModel):
    status: str

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

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

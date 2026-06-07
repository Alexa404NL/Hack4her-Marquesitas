import 'package:flutter/material.dart';
import 'package:h4h_app/services/cart_store.dart';

Widget shopList() {
    return SizedBox(
      height:320,
      child: ListView (
        scrollDirection: Axis.horizontal,
        children: [
          // SKUs match real rows in catalogo_vectorizado so the cart feeds
          // valid embeddings into the pgvector recommendation engine.
          ShopTile(sku: 2618700000000000000, title: "Coca-Cola, Botella Pet 1.25 L, 12 piezas", picture: "assets/images/coca.jpg", price: "\$120.00"),
          ShopTile(sku: 464131000000000000, title: "Ciel Agua Purificada, Botella Pet 1.00 L, 6 piezas", picture: "assets/images/ciel.png", price: "\$45.00"),
          ShopTile(sku: 301419000000000000, title: "Topo Chico Agua Mineral, Botella Pet 1.50 L, 6 piezas", picture: "assets/images/topo.png", price: "\$150.00")
        ],
      ),
    );
}

class ShopTile extends StatefulWidget {
  final int sku;
  final String title;
  final String picture;
  final String price;
  const ShopTile({super.key, required this.sku, required this.title, required this.picture, required this.price});

  @override
  State<ShopTile> createState() => _ShopTileState();
}

class _ShopTileState extends State<ShopTile> {
  int count = 1;

  void _addToCart() {
    CartStore.instance.addItem(
      sku: widget.sku,
      title: widget.title,
      picture: widget.picture,
      price: widget.price,
      quantity: count,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${widget.title} agregado al carrito'),
        duration: const Duration(seconds: 1),
      ),
    );
    setState(() => count = 1);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 335,
      child: Container(
        margin: EdgeInsets.all(8),
        padding: EdgeInsets.fromLTRB(14,10,14,10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1), // light shadow
              blurRadius: 5,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          spacing:10.0,
      
          children: [
            Row(
              spacing: 20.0,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex:1,
                  child: Image.asset(
                    widget.picture,
                    width: 100,
                    height: 100
                  )
                ),
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      Center(
                        child: Text(
                            widget.title,
                            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                        ),
                      ),
                      SizedBox(height: 80),
                      Padding(
                        padding: const EdgeInsets.only(bottom:5),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "Paquetes", 
                            style: TextStyle(fontSize: 14)
                          )
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            height: 40,
                            padding: EdgeInsets.symmetric(horizontal: 64),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: Border.fromBorderSide(BorderSide(color: Colors.grey[400]!)),
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(7.0),
                                bottomLeft: Radius.circular(7.0),
                              ),
                            ),
                            child: Text(count.toString(), style: TextStyle(fontSize: 16),)
                          ),
                          GestureDetector(
                            onTap: () {
                              count++;
                              setState(() => {});
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.only(
                                  topRight: Radius.circular(4.0),
                                  bottomRight: Radius.circular(4.0),
                                ),
                                color:Color.fromARGB(255, 109, 46, 177)
                              ),
                              height:40, 
                              width:40, 
                              child: Icon(Icons.add, color: Colors.white, size: 22),
                            ),
                          )
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: _addToCart,
              child: Container(
                margin: EdgeInsets.fromLTRB(0,2,0,0),
                alignment: Alignment.center,
                height: 42,
                width: 400,
                decoration: BoxDecoration(
                  color: Color.fromARGB(255, 109, 46, 177),
                  borderRadius: BorderRadius.circular(4.0)
                ),
                child: Text(
                  "Agrega $count Paquete${count > 1 ? 's' : ''}",
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w300, color: Colors.white)
                )
              ),
            ),
          ],
        ),
      ),
    );
  }
}
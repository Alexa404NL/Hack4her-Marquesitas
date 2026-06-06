import 'package:flutter/material.dart';

Widget shopList() {
    return SizedBox(
      height:320,
      child: ListView (
        scrollDirection: Axis.horizontal,
        children: [
          ShopTile(title: "Coca-Cola, Botella Pet 1.25 L, 12 piezas", picture: "assets/images/coca.jpg"),
          ShopTile(title: "Ciel Agua Purificada, Botella Pet 1.00 L, 6 piezas", picture: "assets/images/ciel.png"),
          ShopTile(title: "Topo Chico Agua Mineral, Botella Pet 1.50 L, 6 piezas", picture: "assets/images/topo.png")
        ],
      ),
    );
}

class ShopTile extends StatefulWidget {
  final String title;
  final String picture;
  const ShopTile({super.key, required this.title, required this.picture});

  @override
  State<ShopTile> createState() => _ShopTileState();
}

class _ShopTileState extends State<ShopTile> {
  int count = 1;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 360,
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
                            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
                        ),
                      ),
                      SizedBox(height:72),
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
                            width: 156,
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
            Container(
              margin: EdgeInsets.fromLTRB(0,2,0,0),
              alignment: Alignment.center,
              height: 42,
              width: 400,
              decoration: BoxDecoration(
                color: Color.fromARGB(255, 109, 46, 177),
                borderRadius: BorderRadius.circular(4.0)
              ),
              child: Text(
                "Agrega 1 Paquete",
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w300, color: Colors.white)
              )
            ),
          ],
        ),
      ),
    );
  }
}
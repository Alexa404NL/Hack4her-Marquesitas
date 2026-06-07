import 'package:flutter/material.dart';

const _purple = Color(0xff6d2eb1);

Widget shopList() {
  const products = [
    (
      title: 'Coca-Cola, Botella Pet 1.25 L, 12 piezas',
      picture: 'assets/images/coca.jpg',
    ),
    (
      title: 'Ciel Agua Purificada, Botella Pet 1.00 L, 6 piezas',
      picture: 'assets/images/ciel.png',
    ),
    (
      title: 'Topo Chico Agua Mineral, Botella Pet 1.50 L, 6 piezas',
      picture: 'assets/images/topo.png',
    ),
  ];

  return SizedBox(
    height: 338,
    child: ListView.separated(
      padding: const EdgeInsets.only(left: 8, right: 18, bottom: 14),
      scrollDirection: Axis.horizontal,
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return ShopTile(title: product.title, picture: product.picture);
      },
      separatorBuilder: (_, _) => const SizedBox(width: 18),
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
    return Container(
      width: 344,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 122,
                  height: 146,
                  child: Image.asset(widget.picture, fit: BoxFit.contain),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                          color: Color(0xff231f20),
                          height: 1.2,
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        'Paquetes',
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xff231f20),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _QuantityStepper(
                        count: count,
                        onAdd: () => setState(() => count++),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _purple,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              onPressed: () {},
              child: Text(
                'Agrega $count Paquete${count == 1 ? '' : 's'}',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  final int count;
  final VoidCallback onAdd;

  const _QuantityStepper({required this.count, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xffcfcfcf)),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(7),
                  bottomLeft: Radius.circular(7),
                ),
              ),
              child: Text(
                '$count',
                style: const TextStyle(fontSize: 21, color: Color(0xff231f20)),
              ),
            ),
          ),
          SizedBox(
            width: 48,
            height: double.infinity,
            child: IconButton.filled(
              style: IconButton.styleFrom(
                backgroundColor: _purple,
                foregroundColor: Colors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(7),
                    bottomRight: Radius.circular(7),
                  ),
                ),
              ),
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 30),
            ),
          ),
        ],
      ),
    );
  }
}

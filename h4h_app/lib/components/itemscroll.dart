import 'package:flutter/material.dart';

Widget itemListView() {
  const items = [
    ('Pedido Fácil', 'assets/images/pedido.png'),
    ('Refrescos', 'assets/images/refrescos.png'),
    ('Agua', 'assets/images/agua.png'),
    ('Bebidas de fruta', 'assets/images/fruta.png'),
    ('Agua mineral', 'assets/images/mineral.png'),
  ];

  return SizedBox(
    height: 166,
    child: ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 22, 16, 8),
      scrollDirection: Axis.horizontal,
      itemBuilder: (context, index) {
        final item = items[index];
        return _CategoryTile(title: item.$1, imagePath: item.$2);
      },
      separatorBuilder: (_, _) => const SizedBox(width: 18),
      itemCount: items.length,
    ),
  );
}

class _CategoryTile extends StatelessWidget {
  final String title;
  final String imagePath;

  const _CategoryTile({required this.title, required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 112,
      child: Column(
        children: [
          Container(
            width: 112,
            height: 112,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Image.asset(imagePath, fit: BoxFit.contain),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: Color(0xff4c4b4a),
              height: 1.05,
            ),
          ),
        ],
      ),
    );
  }
}

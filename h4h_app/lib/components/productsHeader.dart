import 'package:flutter/material.dart';

Widget productsHeader() {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: const [
        Text(
          'Pedido Fácil',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
        Row(
          children: [
            Text(
              'Ver todos',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w500,
                color: Color(0xffe30625),
              ),
            ),
            SizedBox(width: 10),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 20,
              color: Color(0xffe30625),
            ),
          ],
        ),
      ],
    ),
  );
}

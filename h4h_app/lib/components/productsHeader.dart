import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Widget con el título "Pedido Fácil" a la izquierda
/// y "Ver todos →" a la derecha con estilo rojo.
Widget productsHeader() {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8.0),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Pedido Fácil',
          style: GoogleFonts.lato(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        Row(
          children: [
            Text(
              'Ver todos',
              style: GoogleFonts.lato(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Color.fromARGB(255, 219, 7, 35),
                
              ),
            ),
            SizedBox(width: 13),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: Color.fromARGB(255, 219, 7, 35),
            ),
          ],
        ),
      ],
    ),
  );
}

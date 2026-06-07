import 'package:flutter/material.dart';
import 'package:h4h_app/pages/login.dart';
import 'package:h4h_app/pages/tu_carrito.dart';

const _brandRed = Color(0xffff3b35);
const _ink = Color(0xff231f20);

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      titleSpacing: 16,
      toolbarHeight: 92,
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Punto de venta',
                  style: TextStyle(
                    color: Color(0xff9b9b9b),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 2),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isDense: true,
                    value: null,
                    hint: const Text(
                      'Abarrotes Worms',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: _brandRed,
                      size: 30,
                    ),
                    dropdownColor: Colors.white,
                    items: const [
                      DropdownMenuItem(
                        value: 'logout',
                        child: Text('Cerrar sesión'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == 'logout') {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (context) => const LoginPage(),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Carrito',
            icon: const Icon(
              Icons.shopping_cart_outlined,
              color: _brandRed,
              size: 32,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TuCarrito()),
              );
            },
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TuCarrito()),
              );
            },
            child: Icon(Icons.shopping_cart_outlined, color: Colors.red),
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(74),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: SizedBox(
            height: 48,
            child: TextField(
              style: const TextStyle(fontSize: 20, color: _ink),
              decoration: InputDecoration(
                hintText: 'Buscar',
                hintStyle: const TextStyle(
                  color: Color(0xff5c4c4c),
                  fontSize: 20,
                  fontWeight: FontWeight.w400,
                ),
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(left: 14, right: 10),
                  child: Icon(Icons.search, color: Color(0xff5c4c4c), size: 32),
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 58),
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.zero,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9),
                  borderSide: const BorderSide(color: Color(0xffcfcfcf)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9),
                  borderSide: const BorderSide(color: _brandRed, width: 1.2),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(166);
}

import 'package:flutter/material.dart';
import 'package:h4h_app/pages/dashboard.dart';
import 'package:h4h_app/pages/login.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top:10),
                child: Text("Punto de venta", style: TextStyle(fontSize: 12, color: Colors.grey)),
              ),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isDense: true,
                  value: null,
                  hint: Text(
                    "Abarrotes Worms",
                    style: TextStyle(fontSize: 21, color: Colors.black),
                  ),
                  icon: Icon(Icons.keyboard_arrow_down, color: Colors.red),
                  dropdownColor: Colors.white,
                  items: [
                    DropdownMenuItem(
                      value: "logout",
                      child: Text("Cerrar Sesión", style: TextStyle(fontSize: 18, color: Colors.black)),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == "logout") {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (context) => const LoginPage()),
                      );
                      debugPrint("logout");
                    }
                  },
                ),
              ),
            ],
          ),
          Icon(Icons.shopping_cart_outlined, color: Colors.red),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(60),
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.fromBorderSide(BorderSide(color: Colors.grey[400]!, width:0.5))
            ),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar',
                prefixIcon: Icon(Icons.search),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + 60);
}

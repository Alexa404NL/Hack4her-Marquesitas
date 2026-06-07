import 'package:flutter/material.dart';

class StaticBottomNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int>? onItemSelected;

  const StaticBottomNavigationBar({
    super.key,
    required this.selectedIndex,
    this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      backgroundColor: const Color(0xfffff8f8),
      elevation: 8,
      currentIndex: selectedIndex,
      selectedItemColor: const Color(0xffff3b35),
      unselectedItemColor: const Color(0xff9e9e9e),
      selectedFontSize: 16,
      unselectedFontSize: 16,
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
      onTap: onItemSelected,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home, size: 34), label: 'Inicio'),
        BottomNavigationBarItem(
          icon: Icon(Icons.apps_rounded, size: 32),
          label: 'Productos',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.bookmark, size: 32),
          label: 'Pedidos',
        ),
        BottomNavigationBarItem(icon: Icon(Icons.menu, size: 34), label: 'Menú'),
      ],
    );
  }
}

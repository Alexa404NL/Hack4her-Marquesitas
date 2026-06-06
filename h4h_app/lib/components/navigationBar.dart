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
      currentIndex: selectedIndex,
      selectedItemColor: Colors.red,
      unselectedItemColor: Colors.black,
      onTap: onItemSelected,
      items: [
        _buildNavItem(
          icon: Icons.home,
          label: 'Inicio',
          isSelected: selectedIndex == 0,
        ),
        _buildNavItem(
          icon: Icons.apps,
          label: 'Productos',
          isSelected: selectedIndex == 1,
        ),
        _buildNavItem(
          icon: Icons.book,
          label: 'Pedidos',
          isSelected: selectedIndex == 2,
        ),
        _buildNavItem(
          icon: Icons.menu,
          label: 'Menú',
          isSelected: selectedIndex == 3,
        ),
      ],
    );
  }

  BottomNavigationBarItem _buildNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
  }) {
    return BottomNavigationBarItem(
      icon: Container(
        margin: const EdgeInsets.only(top: 3),
        child: Icon(icon, size: 30),
      ),
      label: label,
    );
  }
}
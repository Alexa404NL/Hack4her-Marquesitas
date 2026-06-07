import 'package:flutter/material.dart';
import 'package:h4h_app/components/appbar.dart';
import 'package:h4h_app/components/itemscroll.dart';
import 'package:h4h_app/components/shoplist.dart';
import 'package:h4h_app/components/pageview.dart'; // este ya lo tienes
import 'package:h4h_app/components/productsHeader.dart';
import 'package:h4h_app/components/navigationBar.dart';
import 'package:h4h_app/pages/metas.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  int _selectedIndex = 0;

  // Pages indexed to the nav bar:
  //  0 → Inicio (home body, built inline below)
  //  1 → Productos (placeholder, shares home for now)
  //  2 → Pedidos  (placeholder, shares home for now)
  //  3 → Metas    ← NEW
  //  4 → Menú     (placeholder)

  Widget _buildBody() {
    if (_selectedIndex == 3) {
      return const MetasPage();
    }
    // All other tabs show the main home content (extend as needed)
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            itemListView(),
            ImageSlider(),
            const SizedBox(height: 20),
            productsHeader(),
            const SizedBox(height: 6),
            shopList(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // MetasPage has its own AppBar, so hide the global one when on Metas.
    final bool showAppBar = _selectedIndex != 3;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 242, 242, 242),
      appBar: showAppBar ? CustomAppBar() : null,
      body: _buildBody(),
      bottomNavigationBar: StaticBottomNavigationBar(
        selectedIndex: _selectedIndex,
        onItemSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }
}

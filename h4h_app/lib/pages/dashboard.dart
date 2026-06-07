import 'package:flutter/material.dart';
import 'package:h4h_app/components/appbar.dart';
import 'package:h4h_app/components/itemscroll.dart';
import 'package:h4h_app/components/navigationBar.dart';
import 'package:h4h_app/components/pageview.dart';
import 'package:h4h_app/components/productsHeader.dart';
import 'package:h4h_app/components/shoplist.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff2f2f2),
      appBar: const CustomAppBar(),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            itemListView(),
            const SizedBox(height: 18),
            const ImageSlider(),
            const SizedBox(height: 34),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: productsHeader(),
            ),
            const SizedBox(height: 20),
            shopList(),
            const SizedBox(height: 10),
          ],
        ),
      ),
      bottomNavigationBar: StaticBottomNavigationBar(
        selectedIndex: _selectedIndex,
        onItemSelected: (index) => setState(() => _selectedIndex = index),
      ),
    );
  }
}

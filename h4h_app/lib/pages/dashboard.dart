import 'package:flutter/material.dart';
import 'package:h4h_app/components/appbar.dart';
import 'package:h4h_app/components/itemscroll.dart';
import 'package:h4h_app/components/shoplist.dart';
import 'package:h4h_app/components/pageview.dart'; // este ya lo tienes
import 'package:h4h_app/components/productsHeader.dart';
import 'package:h4h_app/components/navigationBar.dart';

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
      backgroundColor: Color.fromARGB(255, 242, 242, 242),
      appBar: CustomAppBar(),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16),
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
      ),
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

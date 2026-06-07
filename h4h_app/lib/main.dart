import 'package:flutter/material.dart';
import 'package:h4h_app/pages/dashboard.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      builder: (context, child) {
        return SafeArea(
          top: false,  // Set to true if you want to avoid the notch area as well
          bottom: true, // Prevents overlap with the system navigation bar
          child: child!,
        );
      },
      title: 'H4H App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff6d2eb1)),
        scaffoldBackgroundColor: const Color(0xfff2f2f2),
        useMaterial3: true,
      ),
      home: const Dashboard(),
      routes: {
        '/dashboard': (context) => const Dashboard(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

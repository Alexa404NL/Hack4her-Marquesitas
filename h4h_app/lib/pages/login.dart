import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:h4h_app/pages/dashboard.dart';
import 'package:http/http.dart' as http;

Future<void> login(context) async {
  final response = await http.get(Uri.parse('http://10.22.237.139:8000/login'));
  debugPrint(response.body);
  final data = jsonDecode(response.body);
  
  if (data['status'] == "success") {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => Dashboard()),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Hubo un error. Por favor intente de nuevo.')),
    );
    // Navigator.pushReplacement(
    //   context,
    //   MaterialPageRoute(builder: (context) => LoginPage()),
    // );
  }
}

void signup(context) {
  ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('¡Próximamente!')),
  );
}

// Future<void> signup() async {
//   final response = await http.post(Uri.parse('http://10.0.2.2:8000/signup'));
//   debugPrint(response.body);
// }

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {

  @override
  Widget build(BuildContext context) {
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.red.shade700, Colors.orange.shade400],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom:60.0),
                child: Image.asset("assets/images/Tuali-Blanco.png",
                width: 300,
                  fit: BoxFit.contain
                ),
              ),
              ElevatedButton(
                onPressed: () => login(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.red.shade700,
                  padding: EdgeInsets.symmetric(vertical: 16, horizontal: 74),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text('Login con Voz', style: TextStyle(fontSize: 18)),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => signup(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.red.shade700,
                  padding: EdgeInsets.symmetric(vertical: 16, horizontal: 60),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text('Login con Face ID', style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
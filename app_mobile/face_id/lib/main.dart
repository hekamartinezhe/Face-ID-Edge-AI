import 'package:flutter/material.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const FaceIDApp());
}

class FaceIDApp extends StatelessWidget {
  const FaceIDApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Face-ID Edge AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      // Aquí conectamos tu nueva interfaz
      home: LoginScreen(), 
    );
  }
}

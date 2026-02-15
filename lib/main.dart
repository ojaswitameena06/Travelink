import 'package:flutter/material.dart';
import 'pages/login_page.dart';

void main() {
  runApp(const TravelinkApp());
}

class TravelinkApp extends StatelessWidget {
  const TravelinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LoginPage(),
    );
  }
}

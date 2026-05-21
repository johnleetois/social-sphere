import 'package:flutter/material.dart';
import 'screens/intro_screen.dart';

void main() {
  runApp(SocialSphereApp());
}

class SocialSphereApp extends StatelessWidget {
  const SocialSphereApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Social Sphere',
      debugShowCheckedModeBanner: false,
      home: const IntroScreen(),
    );
  }
}

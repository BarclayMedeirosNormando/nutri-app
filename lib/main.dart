import 'package:flutter/material.dart';

import 'screens/login_screen.dart';
import 'widgets/update_banner.dart';

void main() {
  runApp(const NutriApp());
}

class NutriApp extends StatelessWidget {
  const NutriApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nutri App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      builder: (context, child) =>
          UpdateBanner(child: child ?? const SizedBox.shrink()),
      home: const LoginScreen(),
    );
  }
}

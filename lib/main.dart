import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const SarcopeniaApp());
}

class SarcopeniaApp extends StatelessWidget {
  const SarcopeniaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '근감소증 위험 평가',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const HomeScreen(),
    );
  }
}

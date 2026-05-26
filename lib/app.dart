import 'package:flutter/material.dart';

import 'features/home/home_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Dyslexia App',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFBFAF3),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF63B5D2),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
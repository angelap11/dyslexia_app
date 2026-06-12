import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'features/auth/auth_service.dart';
import 'features/auth/login_screen.dart';
import 'features/home/home_screen.dart';
import 'features/settings/provider.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final provider = SettingsProvider();
        provider.loadSettings();
        return provider;
      },
      child: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Dyslexia App',

            theme: ThemeData(
              useMaterial3: true,
              scaffoldBackgroundColor: const Color(0xFFFBFAF3),
              fontFamily: settings.dyslexiaFont ? 'DyslexicFont' : null,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF63B5D2),
              ),
            ),

            home: StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasData && snapshot.data != null) {
                  return const HomeScreen();
                }

                return const LoginScreen();
              },
            ),
            // home: const Scaffold(
            //   body: Center(child: Text("MY APP IS RUNNING")),
            // ),
          );
        },
      ),
    );
  }
}
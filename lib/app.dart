// import 'package:flutter/material.dart';
//
// import 'features/home/home_screen.dart';
// import 'features/auth/auth_service.dart';
// import 'features/auth/login_screen.dart';
//
// class MyApp extends StatefulWidget {
//   const MyApp({super.key});
//
//   static _MyAppState? of(BuildContext context) {
//     return context.findAncestorStateOfType<_MyAppState>();
//   }
//
//   @override
//   State<MyApp> createState() => _MyAppState();
// }
//
// class _MyAppState extends State<MyApp> {
//   bool darkMode = false;
//   bool dyslexiaFont = true;
//
//   Future<bool> _checkLoginStatus() async {
//     return AuthService().isLoggedIn();
//   }
//
//   void updateSettings({
//     bool? darkModeValue,
//     bool? dyslexiaFontValue,
//   }) {
//     setState(() {
//       if (darkModeValue != null) {
//         darkMode = darkModeValue;
//       }
//
//       if (dyslexiaFontValue != null) {
//         dyslexiaFont = dyslexiaFontValue;
//       }
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       debugShowCheckedModeBanner: false,
//       title: 'Dyslexia App',
//
//       themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
//
//       theme: ThemeData(
//         useMaterial3: true,
//         brightness: Brightness.light,
//
//         scaffoldBackgroundColor: const Color(0xFFFBFAF3),
//
//         fontFamily: dyslexiaFont ? 'DyslexicFont' : null,
//
//         colorScheme: ColorScheme.fromSeed(
//           seedColor: const Color(0xFF63B5D2),
//           brightness: Brightness.light,
//         ),
//       ),
//
//       darkTheme: ThemeData(
//         useMaterial3: true,
//         brightness: Brightness.dark,
//
//         scaffoldBackgroundColor: const Color(0xFF121212),
//
//         fontFamily: dyslexiaFont ? 'DyslexicFont' : 'Roboto',
//
//         colorScheme: ColorScheme.fromSeed(
//           seedColor: const Color(0xFF63B5D2),
//           brightness: Brightness.dark,
//         ),
//       ),
//
//       home: FutureBuilder<bool>(
//         future: _checkLoginStatus(),
//         builder: (context, snapshot) {
//           if (!snapshot.hasData) {
//             return const Scaffold(
//               body: Center(
//                 child: CircularProgressIndicator(),
//               ),
//             );
//           }
//
//           if (snapshot.data == true) {
//             return const HomeScreen();
//           }
//
//           return const LoginScreen();
//         },
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'features/auth/auth_service.dart';
import 'features/auth/login_screen.dart';
import 'features/home/home_screen.dart';
import 'features/settings/provider.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<bool> _checkLoginStatus() async {
    return AuthService().isLoggedIn();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SettingsProvider>(
      create: (context) {
        final provider = SettingsProvider();
        provider.loadSettings();
        return provider;
      },
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Dyslexia App',
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFFBFAF3),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF63B5D2),
          ),
        ),
        home: FutureBuilder<bool>(
          future: _checkLoginStatus(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (snapshot.data == true) {
              return const HomeScreen();
            }

            return const LoginScreen();
          },
        ),
      ),
    );
  }
}

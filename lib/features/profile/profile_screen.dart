// import 'package:flutter/material.dart';
//
// import '../home/home_screen.dart';
// import '../tts/tts_screen.dart';
// import '../ocr/ocr_screen.dart';
// import '../settings/settings_screen.dart';
// import '../../widgets/app_bottom_nav.dart';
//
// import 'profile_widgets/profile_header.dart';
// import 'profile_widgets/profile_history_card.dart';
//
// import '../auth/auth_service.dart';
// import '../auth/login_screen.dart';
//
// import '../location/location_service.dart';
//
// class ProfileScreen extends StatefulWidget {
//   const ProfileScreen({super.key});
//
//   @override
//   State<ProfileScreen> createState() => _ProfileScreenState();
// }
//
// class _ProfileScreenState extends State<ProfileScreen> {
//   final AuthService _authService = AuthService();
//   final LocationService _locationService = LocationService();
//
//
//   String userName = 'Корисник';
//
//   @override
//   void initState() {
//     super.initState();
//     _loadUserData();
//   }
//
//   Future<void> _loadUserData() async {
//     try {
//       final name = await _authService.getCurrentUserName();
//
//       if (!mounted) return;
//
//       setState(() {
//         userName = name ?? 'Корисник';
//       });
//     } catch (_) {}
//   }
//
//   void _open(BuildContext context, Widget screen) {
//     Navigator.push(
//       context,
//       MaterialPageRoute(builder: (_) => screen),
//     );
//   }
//
//   Future<void> _logout() async {
//     await _authService.logout();
//
//     if (!mounted) return;
//
//     Navigator.pushAndRemoveUntil(
//       context,
//       MaterialPageRoute(
//         builder: (_) => const LoginScreen(),
//       ),
//           (route) => false,
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Theme.of(context).scaffoldBackgroundColor,
//       body: SafeArea(
//         child: Column(
//           children: [
//             Expanded(
//               child: SingleChildScrollView(
//                 padding: const EdgeInsets.fromLTRB(24, 30, 24, 20),
//                 child: Column(
//                   children: [
//                     const SizedBox(height: 20),
//
//                     ProfileHeader(
//                       userName: userName,
//                     ),
//
//                     const SizedBox(height: 30),
//
//                     const ProfileHistoryCard(),
//
//                     const SizedBox(height: 16),
//
//                     InkWell(
//                       onTap: _logout,
//                       borderRadius: BorderRadius.circular(24),
//                       child: Container(
//                         width: double.infinity,
//                         padding: const EdgeInsets.symmetric(
//                           horizontal: 20,
//                           vertical: 18,
//                         ),
//                         decoration: BoxDecoration(
//                           color: Colors.white,
//                           borderRadius: BorderRadius.circular(24),
//                           border: Border.all(
//                             color: const Color(0xFFE7E1D5),
//                           ),
//                           boxShadow: [
//                             BoxShadow(
//                               color: Colors.red.withOpacity(0.08),
//                               blurRadius: 20,
//                               offset: const Offset(0, 10),
//                             ),
//                           ],
//                         ),
//                         child: const Row(
//                           children: [
//                             CircleAvatar(
//                               radius: 26,
//                               backgroundColor: Color(0xFFFFE5E5),
//                               child: Icon(
//                                 Icons.logout_rounded,
//                                 color: Colors.red,
//                               ),
//                             ),
//                             SizedBox(width: 16),
//                             Expanded(
//                               child: Column(
//                                 crossAxisAlignment:
//                                 CrossAxisAlignment.start,
//                                 children: [
//                                   Text(
//                                     'Одјави се',
//                                     style: TextStyle(
//                                       fontSize: 18,
//                                       fontWeight: FontWeight.w800,
//                                       color: Colors.red,
//                                     ),
//                                   ),
//                                   SizedBox(height: 4),
//                                   Text(
//                                     'Излези од твојот профил',
//                                     style: TextStyle(
//                                       fontSize: 14,
//                                       color: Color(0xFF5E6677),
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                             Icon(
//                               Icons.arrow_forward_ios_rounded,
//                               size: 16,
//                               color: Color(0xFF5E6677),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//
//             AppBottomNav(
//               currentIndex: 3,
//               onHomeTap: () => _open(context, const HomeScreen()),
//               onReadTap: () => _open(context, const TtsScreen()),
//               onScanTap: () => _open(context, const OcrScreen()),
//               onProfileTap: () {},
//               onSettingsTap: () => _open(context, const SettingsScreen()),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';

import '../home/home_screen.dart';
import '../tts/tts_screen.dart';
import '../ocr/ocr_screen.dart';
import '../settings/settings_screen.dart';
import '../../widgets/app_bottom_nav.dart';

import 'profile_widgets/profile_header.dart';
import 'profile_widgets/profile_history_card.dart';

import '../auth/auth_service.dart';
import '../auth/login_screen.dart';
import '../location/location_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final LocationService _locationService = LocationService();

  String userName = 'Корисник';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final name = await _authService.getCurrentUserName();

    if (!mounted) return;

    setState(() {
      userName = name ?? 'Корисник';
    });
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  Future<void> _openNearbyCenters() async {
    final ok = await _locationService.openNearbySupportCenters();

    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не може да се отвори локацијата или нема дозвола.'),
        ),
      );
    }
  }

  Future<void> _logout() async {
    await _authService.logout();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 30, 24, 20),
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    ProfileHeader(
                      userName: userName,
                    ),

                    const SizedBox(height: 30),

                    const ProfileHistoryCard(),

                    const SizedBox(height: 16),

                    _ProfileOptionCard(
                      icon: Icons.location_on_outlined,
                      iconColor: const Color(0xFF3196C2),
                      backgroundColor: const Color(0xFFCFF2FF),
                      title: 'Центри во близина',
                      subtitle: 'Најди библиотеки, логопеди и центри за поддршка',
                      onTap: _openNearbyCenters,
                    ),

                    const SizedBox(height: 16),

                    _ProfileOptionCard(
                      icon: Icons.logout_rounded,
                      iconColor: Colors.red,
                      backgroundColor: const Color(0xFFFFE5E5),
                      title: 'Одјави се',
                      subtitle: 'Излези од твојот профил',
                      onTap: _logout,
                      isDanger: true,
                    ),
                  ],
                ),
              ),
            ),

            AppBottomNav(
              currentIndex: 3,
              onHomeTap: () => _open(context, const HomeScreen()),
              onReadTap: () => _open(context, const TtsScreen()),
              onScanTap: () => _open(context, const OcrScreen()),
              onProfileTap: () {},
              onSettingsTap: () => _open(context, const SettingsScreen()),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileOptionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDanger;

  const _ProfileOptionCard({
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFFE7E1D5),
          ),
          boxShadow: [
            BoxShadow(
              color: isDanger
                  ? Colors.red.withOpacity(0.08)
                  : Colors.black.withOpacity(0.025),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: backgroundColor,
              child: Icon(
                icon,
                color: iconColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDanger
                          ? Colors.red
                          : const Color(0xFF07162E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF5E6677),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: Color(0xFF5E6677),
            ),
          ],
        ),
      ),
    );
  }
}
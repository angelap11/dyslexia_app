// import 'package:flutter/material.dart';
//
// import '../../app.dart';
// import '../home/home_screen.dart';
// import '../tts/tts_screen.dart';
// import '../ocr/ocr_screen.dart';
// import '../profile/profile_screen.dart';
// import '../../widgets/app_bottom_nav.dart';
//
// import 'settings_widgets/settings_header.dart';
// import 'settings_widgets/switch_setting_card.dart';
// import 'settings_widgets/slider_setting_card.dart';
// import 'settings_widgets/language_setting_card.dart';
//
// class SettingsScreen extends StatefulWidget {
//   const SettingsScreen({super.key});
//
//   @override
//   State<SettingsScreen> createState() => _SettingsScreenState();
// }
//
// class _SettingsScreenState extends State<SettingsScreen> {
//   bool darkTheme = false;
//   bool dyslexiaFont = false;
//   double fontSize = 17;
//
//   void _open(BuildContext context, Widget screen) {
//     Navigator.push(
//       context,
//       MaterialPageRoute(builder: (_) => screen),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Theme.of(context).scaffoldBackgroundColor,
//
//       body: SafeArea(
//         child: Column(
//           children: [
//             Expanded(
//               child: SingleChildScrollView(
//                 padding: const EdgeInsets.fromLTRB(28, 70, 28, 34),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     const SettingsHeader(),
//
//                     const SizedBox(height: 52),
//
//                     SwitchSettingCard(
//                       icon: Icons.dark_mode_outlined,
//                       title: 'Темна тема',
//                       subtitle: 'Поудобно за вечерно читање',
//                       value: darkTheme,
//                       onChanged: (v) {
//                         setState(() => darkTheme = v);
//
//                         MyApp.of(context)?.updateSettings(
//                           darkModeValue: v,
//                         );
//                       },
//                     ),
//
//                     const SizedBox(height: 20),
//
//                     SwitchSettingCard(
//                       icon: Icons.auto_awesome_outlined,
//                       title: 'Дислексија фонт',
//                       subtitle: 'OpenDyslexic + поголем простор',
//                       value: dyslexiaFont,
//                       onChanged: (v) {
//                         setState(() => dyslexiaFont = v);
//
//                         MyApp.of(context)?.updateSettings(
//                           dyslexiaFontValue: v,
//                         );
//                       },
//                     ),
//
//                     const SizedBox(height: 20),
//
//                     SliderSettingCard(
//                       fontSize: fontSize,
//                       onChanged: (v) =>
//                           setState(() => fontSize = v),
//                     ),
//
//                     const SizedBox(height: 20),
//
//                     const LanguageSettingCard(),
//
//                     const SizedBox(height: 48),
//                   ],
//                 ),
//               ),
//             ),
//
//             AppBottomNav(
//               currentIndex: 4,
//               onHomeTap: () => _open(context, const HomeScreen()),
//               onReadTap: () => _open(context, const TtsScreen()),
//               onScanTap: () => _open(context, const OcrScreen()),
//               onProfileTap: () => _open(context, const ProfileScreen()),
//               onSettingsTap: () {},
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../home/home_screen.dart';
import '../tts/tts_screen.dart';
import '../ocr/ocr_screen.dart';
import '../profile/profile_screen.dart';
import 'provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _goToHome(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  void _goToRead(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const TtsScreen()),
    );
  }

  void _goToScan(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const OcrScreen()),
    );
  }

  void _goToProfile(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFFBFAF3),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 70, 28, 34),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Поставки',
                      style: TextStyle(
                        color: Color(0xFF07162E),
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 14),

                    const Text(
                      'Прилагоди го читањето според себе',
                      style: TextStyle(
                        color: Color(0xFF505A70),
                        fontSize: 20,
                        height: 1.35,
                      ),
                    ),

                    const SizedBox(height: 42),

                    _SwitchSettingCard(
                      icon: Icons.auto_awesome_outlined,
                      title: 'Дислексија фонт',
                      subtitle: 'Прикажување со полесен фонт за читање',
                      value: settings.dyslexiaFont,
                      onChanged: settings.setDyslexiaFont,
                    ),

                    const SizedBox(height: 20),

                    _SwitchSettingCard(
                      icon: Icons.center_focus_strong,
                      title: 'Focus Mode',
                      subtitle: 'Помалку одвлекување внимание при читање',
                      value: settings.focusMode,
                      onChanged: settings.setFocusMode,
                    ),

                    const SizedBox(height: 20),

                    _SliderSettingCard(
                      icon: Icons.record_voice_over_rounded,
                      title: 'Брзина на читање',
                      valueLabel: settings.speechRate.toStringAsFixed(1),
                      value: settings.speechRate,
                      min: 0.1,
                      max: 1.0,
                      divisions: 9,
                      onChanged: settings.setSpeechRate,
                    ),

                    const SizedBox(height: 20),

                    _SliderSettingCard(
                      icon: Icons.text_fields_rounded,
                      title: 'Големина на фонт',
                      valueLabel: '${settings.fontSize.round()}px',
                      value: settings.fontSize,
                      min: 14,
                      max: 26,
                      divisions: 12,
                      onChanged: settings.setFontSize,
                      preview: Text(
                        'Преглед на текст',
                        style: TextStyle(
                          color: const Color(0xFF07162E),
                          fontSize: settings.fontSize,
                          height: 1.4,
                          fontFamily:
                          settings.dyslexiaFont ? 'DyslexicFont' : null,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(
                          color: const Color(0xFFE7E1D5),
                        ),
                      ),
                      child: Row(
                        children: [
                          const _SettingIcon(
                            icon: Icons.language_rounded,
                          ),
                          const SizedBox(width: 18),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Јазик',
                                  style: TextStyle(
                                    color: Color(0xFF07162E),
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Македонски (кирилица)',
                                  style: TextStyle(
                                    color: Color(0xFF505A70),
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE3F0E7),
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: const Text(
                              'MK',
                              style: TextStyle(
                                color: Color(0xFF07162E),
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 48),

                    const Center(
                      child: Text(
                        'ЧитајЛесно · v1.0',
                        style: TextStyle(
                          color: Color(0xFF505A70),
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            _BottomNavBar(
              currentIndex: 4,
              onHomeTap: () => _goToHome(context),
              onReadTap: () => _goToRead(context),
              onScanTap: () => _goToScan(context),
              onProfileTap: () => _goToProfile(context),
              onSettingsTap: () {},
            ),
          ],
        ),
      ),
    );
  }
}

class _SwitchSettingCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchSettingCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: const Color(0xFFE7E1D5),
        ),
      ),
      child: Row(
        children: [
          _SettingIcon(icon: icon),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF07162E),
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF505A70),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: Colors.white,
            activeTrackColor: const Color(0xFF7DD3C7),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFFE8E5DC),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _SliderSettingCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;
  final Widget? preview;

  const _SliderSettingCard({
    required this.icon,
    required this.title,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    this.preview,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: const Color(0xFFE7E1D5),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _SettingIcon(icon: icon),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF07162E),
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      valueLabel,
                      style: const TextStyle(
                        color: Color(0xFF505A70),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            activeColor: const Color(0xFF63B5D2),
            inactiveColor: const Color(0xFFE8E5DC),
            onChanged: onChanged,
          ),

          if (preview != null) ...[
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 20,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFF1EEE8),
                borderRadius: BorderRadius.circular(18),
              ),
              child: preview,
            ),
          ],
        ],
      ),
    );
  }
}

class _SettingIcon extends StatelessWidget {
  final IconData icon;

  const _SettingIcon({
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: const Color(0xFFCFF2FF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(
        icon,
        color: const Color(0xFF3196C2),
        size: 31,
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final VoidCallback onHomeTap;
  final VoidCallback onReadTap;
  final VoidCallback onScanTap;
  final VoidCallback onProfileTap;
  final VoidCallback onSettingsTap;

  const _BottomNavBar({
    required this.currentIndex,
    required this.onHomeTap,
    required this.onReadTap,
    required this.onScanTap,
    required this.onProfileTap,
    required this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 112,
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: const Color(0xFFE7E1D5).withOpacity(0.8),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _BottomNavItem(
            icon: Icons.home_outlined,
            label: 'Дома',
            selected: currentIndex == 0,
            onTap: onHomeTap,
          ),
          _BottomNavItem(
            icon: Icons.menu_book_outlined,
            label: 'Читај',
            selected: currentIndex == 1,
            onTap: onReadTap,
          ),
          _BottomNavItem(
            icon: Icons.document_scanner_outlined,
            label: 'Скенирај',
            selected: currentIndex == 2,
            onTap: onScanTap,
          ),
          _BottomNavItem(
            icon: Icons.person_outline_rounded,
            label: 'Профил',
            selected: currentIndex == 3,
            onTap: onProfileTap,
          ),
          _BottomNavItem(
            icon: Icons.settings_outlined,
            label: 'Поставки',
            selected: currentIndex == 4,
            onTap: onSettingsTap,
          ),
        ],
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color activeColor = const Color(0xFF3196C2);
    final Color inactiveColor = const Color(0xFF5E6677);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFCFF2FF) : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 29,
              color: selected ? activeColor : inactiveColor,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: selected ? activeColor : inactiveColor,
            ),
          ),
        ],
      ),
    );
  }
}
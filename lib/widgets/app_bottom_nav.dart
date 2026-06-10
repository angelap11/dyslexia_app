import 'package:flutter/material.dart';

class AppBottomNav extends StatelessWidget {
  final int currentIndex;

  final VoidCallback onHomeTap;
  final VoidCallback onReadTap;
  final VoidCallback onScanTap;
  final VoidCallback onProfileTap;
  final VoidCallback onSettingsTap;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onHomeTap,
    required this.onReadTap,
    required this.onScanTap,
    required this.onProfileTap,
    required this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = const Color(0xFF3196C2);
    final inactiveColor = const Color(0xFF5E6677);

    return Container(
      height: 105,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: const Color(0xFFE7E1D5).withOpacity(0.8),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Item(
            icon: Icons.home_outlined,
            label: 'Дома',
            selected: currentIndex == 0,
            color: currentIndex == 0 ? activeColor : inactiveColor,
            onTap: onHomeTap,
          ),
          _Item(
            icon: Icons.menu_book_outlined,
            label: 'Читај',
            selected: currentIndex == 1,
            color: currentIndex == 1 ? activeColor : inactiveColor,
            onTap: onReadTap,
          ),
          _Item(
            icon: Icons.document_scanner_outlined,
            label: 'Скенирај',
            selected: currentIndex == 2,
            color: currentIndex == 2 ? activeColor : inactiveColor,
            onTap: onScanTap,
          ),
          _Item(
            icon: Icons.person_outline_rounded,
            label: 'Профил',
            selected: currentIndex == 3,
            color: currentIndex == 3 ? activeColor : inactiveColor,
            onTap: onProfileTap,
          ),
          _Item(
            icon: Icons.settings_outlined,
            label: 'Поставки',
            selected: currentIndex == 4,
            color: currentIndex == 4 ? activeColor : inactiveColor,
            onTap: onSettingsTap,
          ),
        ],
      ),
    );
  }
}

class _Item extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _Item({
    required this.icon,
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? const Color(0xFFCFF2FF) : Colors.transparent,
            ),
            child: Icon(icon, size: 26, color: color),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
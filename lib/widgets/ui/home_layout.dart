import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Shared page padding. Layout stays a single vertical column on every screen.
class HomeLayout {
  static const double compactBreakpoint = 400;

  static bool isCompact(double width) => width < compactBreakpoint;

  static double horizontalPadding(double width) {
    if (width >= 1024) return AppSpacing.huge;
    if (width >= 768) return AppSpacing.xxxl;
    return AppSpacing.xxl;
  }

  static Widget constrain({
    required double screenWidth,
    required Widget child,
    double? maxWidth,
  }) {
    final pad = horizontalPadding(screenWidth);
    final available = (screenWidth - pad * 2).clamp(0, double.infinity);
    // Comfortable reading width on tablet / desktop / web.
    final defaultCap = screenWidth >= 1440
        ? 880.0
        : screenWidth >= 1024
        ? 760.0
        : screenWidth >= 768
        ? 640.0
        : available;
    final cap = maxWidth ?? defaultCap;
    final maxW = available < cap ? available : cap;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW.toDouble()),
        child: child,
      ),
    );
  }
}

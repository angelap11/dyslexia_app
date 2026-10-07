import 'package:flutter/material.dart';

/// Visual identity: calm educational companion for ages ~7–13.
/// Friendly teal primary + controlled supporting accents.
class AppColors {
  // Brand — friendly teal / blue
  static const primary = Color(0xFF2F8F9D);
  static const primaryLight = Color(0xFF4EB0BC);
  static const coral = Color(0xFFF28B6C);
  static const lavender = Color(0xFF9B8FD9);
  static const mint = Color(0xFF5CBFA6);
  static const gold = Color(0xFFE8C45A);
  static const sky = Color(0xFF7EB8D4);

  // Soft tint fills (section accents — use sparingly)
  static const softTeal = Color(0xFFD5EEF1);
  static const softSky = Color(0xFFD9ECF6);
  static const softYellow = Color(0xFFF7E9B8);
  static const softCoral = Color(0xFFFAD9CE);
  static const softMint = Color(0xFFD4F0E7);
  static const softLavender = Color(0xFFE4DFF6);

  // Surfaces — light (warm off-white)
  static const backgroundLight = Color(0xFFFBF8F3);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const surfaceMutedLight = Color(0xFFF3EFE8);
  static const borderLight = Color(0xFFE6E0D6);

  // Surfaces — dark
  static const backgroundDark = Color(0xFF12181E);
  static const surfaceDark = Color(0xFF1B2430);
  static const surfaceMutedDark = Color(0xFF252F3C);
  static const borderDark = Color(0xFF334050);

  // Text
  static const textPrimaryLight = Color(0xFF1A2332);
  static const textSecondaryLight = Color(0xFF5F6B7A);
  static const textPrimaryDark = Color(0xFFF5F3EF);
  static const textSecondaryDark = Color(0xFFA0AAB8);

  // Semantic
  static const success = Color(0xFF5CBFA6);
  static const warning = Color(0xFFE8C45A);
  static const error = Color(0xFFE57373);
  static const info = Color(0xFF7EB8D4);

  // Decorative blob tints (kept soft; hide in focus / high contrast)
  static const blobSage = Color(0xFFC5E6E8);
  static const blobPeach = Color(0xFFFAD9CE);
  static const blobLavender = Color(0xFFE0D9F5);
  static const blobSky = Color(0xFFD4EAF5);

  // Legacy aliases used by existing widgets
  static const secondary = mint;
  static const accent = lavender;
  static const accentWarm = coral;
  static const navActive = primary;
  static const navInactive = Color(0xFF8A929E);
  static const navHighlight = Color(0xFFD5EEF1);

  static const heroGradient = LinearGradient(
    colors: [Color(0xFF2F8F9D), Color(0xFF4EB0BC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const ocrGradient = LinearGradient(
    colors: [Color(0xFF5CBFA6), Color(0xFF2F8F9D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const primaryButtonGradient = LinearGradient(
    colors: [Color(0xFF2F8F9D), Color(0xFF4EB0BC)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}

/// Spacing scale — slightly airy for readability and large touch areas.
class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;
  static const huge = 48.0;
}

/// Corner radii — soft cards (~18–24) with larger hero moments.
class AppRadius {
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
  static const xxl = 28.0;
  static const pill = 999.0;
  static const hero = 28.0;
  static const card = 22.0;
}

/// Subtle motion tokens — short, non-distracting.
class AppMotion {
  static const Duration instant = Duration(milliseconds: 80);
  static const Duration tap = Duration(milliseconds: 120);
  static const Duration short = Duration(milliseconds: 180);
  static const Duration medium = Duration(milliseconds: 280);

  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasize = Curves.easeOutBack;

  /// Pressed scale for interactive tiles / buttons.
  static const double tapScale = 0.97;
  static const double tapScaleStrong = 0.94;
}

/// Comfortable touch targets for children and accessibility.
class AppTouch {
  static const double min = 48.0;
  static const double comfortable = 56.0;
  static const double large = 64.0;
}

/// Soft elevation helpers — prefer subtle depth over heavy shadows.
class AppElevation {
  static List<BoxShadow> none = const [];

  static List<BoxShadow> soft(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: dark ? 0.28 : 0.05),
        blurRadius: 14,
        offset: const Offset(0, 4),
      ),
    ];
  }

  static List<BoxShadow> card(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: dark ? 0.32 : 0.06),
        blurRadius: 18,
        offset: const Offset(0, 6),
      ),
    ];
  }

  static List<BoxShadow> primaryGlow([double alpha = 0.22]) {
    return [
      BoxShadow(
        color: AppColors.primary.withValues(alpha: alpha),
        blurRadius: 16,
        offset: const Offset(0, 6),
      ),
    ];
  }
}

ThemeData buildAppTheme({
  required bool dyslexiaFont,
  required bool isDark,
  bool focusMode = false,
  bool highContrast = false,
}) {
  final Color bg;
  final Color surface;
  final Color surfaceMuted;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color primary;

  if (highContrast) {
    if (isDark) {
      bg = const Color(0xFF000000);
      surface = const Color(0xFF121212);
      surfaceMuted = const Color(0xFF1E1E1E);
      textPrimary = const Color(0xFFFFFFFF);
      textSecondary = const Color(0xFFE6E6E6);
      border = const Color(0xFFBDBDBD);
      primary = const Color(0xFF5AD1D1);
    } else {
      bg = const Color(0xFFFFFFFF);
      surface = const Color(0xFFFFFFFF);
      surfaceMuted = const Color(0xFFF2F2F2);
      textPrimary = const Color(0xFF000000);
      textSecondary = const Color(0xFF222222);
      border = const Color(0xFF1A1A1A);
      primary = const Color(0xFF0F5C5C);
    }
  } else {
    bg = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    surface = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    surfaceMuted = isDark
        ? AppColors.surfaceMutedDark
        : AppColors.surfaceMutedLight;
    textPrimary = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    textSecondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    border = isDark ? AppColors.borderDark : AppColors.borderLight;
    primary = AppColors.primary;
  }

  final bodyLineHeight = dyslexiaFont
      ? (focusMode ? 2.0 : 1.85)
      : (focusMode ? 1.8 : 1.6);
  final bodyLetterSpacing = dyslexiaFont
      ? (focusMode ? 0.65 : 0.5)
      : (focusMode ? 0.2 : 0.0);
  final secondaryLineHeight = dyslexiaFont
      ? (focusMode ? 1.9 : 1.75)
      : (focusMode ? 1.65 : 1.5);

  return ThemeData(
    useMaterial3: true,
    brightness: isDark ? Brightness.dark : Brightness.light,
    scaffoldBackgroundColor: bg,
    fontFamily: dyslexiaFont ? 'DyslexicFont' : null,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      brightness: isDark ? Brightness.dark : Brightness.light,
      primary: primary,
      surface: surface,
      onSurface: textPrimary,
      onSurfaceVariant: textSecondary,
      outline: border,
    ),
    extensions: [
      AppPalette(
        surfaceMuted: surfaceMuted,
        border: border,
        textPrimary: textPrimary,
        textSecondary: textSecondary,
        highContrast: highContrast,
      ),
    ],
    textTheme: TextTheme(
      displayLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: textPrimary,
        height: 1.2,
        letterSpacing: dyslexiaFont ? 0.55 : -0.2,
      ),
      headlineMedium: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        color: textPrimary,
        height: 1.25,
        letterSpacing: dyslexiaFont ? 0.35 : 0,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        height: 1.35,
      ),
      titleMedium: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        height: 1.4,
      ),
      bodyLarge: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w400,
        color: textPrimary,
        height: bodyLineHeight,
        letterSpacing: bodyLetterSpacing,
        wordSpacing: focusMode ? 1.5 : 0,
      ),
      bodyMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: textSecondary,
        height: secondaryLineHeight,
        letterSpacing: focusMode ? 0.15 : 0,
      ),
      // Section labels — sentence case friendly; avoid dense ALL-CAPS tracking.
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: textSecondary,
        letterSpacing: dyslexiaFont ? 0.2 : 0.15,
        height: 1.3,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: IconThemeData(color: textPrimary),
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: textPrimary,
        height: 1.25,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceMuted,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: highContrast
            ? BorderSide(color: border, width: 1.5)
            : BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: highContrast
            ? BorderSide(color: border, width: 1.5)
            : BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: BorderSide(color: primary, width: 2),
      ),
      labelStyle: TextStyle(color: textSecondary, fontSize: 15),
      hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.7)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((_) => Colors.white),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return primary;
        return highContrast
            ? (isDark ? const Color(0xFF555555) : const Color(0xFF9E9E9E))
            : (isDark ? AppColors.borderDark : const Color(0xFFD5D0C8));
      }),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: primary,
      inactiveTrackColor: highContrast
          ? (isDark ? const Color(0xFF555555) : const Color(0xFFBDBDBD))
          : (isDark ? AppColors.borderDark : const Color(0xFFD5D0C8)),
      thumbColor: primary,
      overlayColor: primary.withValues(alpha: 0.1),
      trackHeight: 8,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(AppTouch.min, AppTouch.comfortable),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.md,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          height: 1.2,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(AppTouch.min, AppTouch.comfortable),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.md,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xxl),
      ),
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: textPrimary,
        height: 1.3,
      ),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: border),
      ),
      margin: EdgeInsets.zero,
    ),
    dividerTheme: DividerThemeData(
      color: border,
      thickness: highContrast ? 1.5 : 1,
    ),
  );
}

@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final Color surfaceMuted;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final bool highContrast;

  const AppPalette({
    required this.surfaceMuted,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.highContrast,
  });

  @override
  AppPalette copyWith({
    Color? surfaceMuted,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    bool? highContrast,
  }) {
    return AppPalette(
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      highContrast: highContrast ?? this.highContrast,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      highContrast: t < 0.5 ? highContrast : other.highContrast,
    );
  }
}

extension AppThemeExtension on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  AppPalette get appPalette =>
      Theme.of(this).extension<AppPalette>() ??
      AppPalette(
        surfaceMuted: isDark
            ? AppColors.surfaceMutedDark
            : AppColors.surfaceMutedLight,
        border: isDark ? AppColors.borderDark : AppColors.borderLight,
        textPrimary: isDark
            ? AppColors.textPrimaryDark
            : AppColors.textPrimaryLight,
        textSecondary: isDark
            ? AppColors.textSecondaryDark
            : AppColors.textSecondaryLight,
        highContrast: false,
      );

  bool get highContrast => appPalette.highContrast;

  Color get appBackground => Theme.of(this).scaffoldBackgroundColor;

  Color get appSurface => Theme.of(this).colorScheme.surface;

  Color get appSurfaceMuted => appPalette.surfaceMuted;

  Color get appBorder => appPalette.border;

  Color get appTextPrimary => appPalette.textPrimary;

  Color get appTextSecondary => appPalette.textSecondary;
}

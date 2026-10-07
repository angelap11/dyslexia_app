import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/settings/provider.dart';
import 'theme.dart';

extension AccessibilityContext on BuildContext {
  SettingsProvider get appSettings => watch<SettingsProvider>();

  SettingsProvider get appSettingsRead => read<SettingsProvider>();

  /// Typography for long-form reading areas (OCR, TTS editor).
  TextStyle readingTextStyle({bool? useDyslexiaFont}) {
    final settings = appSettingsRead;
    final themeStyle = Theme.of(this).textTheme.bodyLarge!;
    final dyslexia = useDyslexiaFont ?? settings.dyslexiaFont;

    return themeStyle.copyWith(
      fontFamily: dyslexia ? 'DyslexicFont' : themeStyle.fontFamily,
      color: appTextPrimary,
    );
  }
}

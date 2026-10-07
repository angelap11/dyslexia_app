import 'package:flutter/widgets.dart';

/// Whether the soft keyboard / IME is currently visible.
///
/// Prefer this over [FocusNode.hasFocus]: focus can remain true after the
/// Android keyboard is dismissed, which must not keep chrome hidden.
bool isKeyboardVisible(BuildContext context) =>
    MediaQuery.viewInsetsOf(context).bottom > 0;

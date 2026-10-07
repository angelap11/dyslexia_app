import 'dart:ui' show TextRange;

final RegExp _whitespace = RegExp(r'\s');
final RegExp _wordCharacter = RegExp(r'[\p{L}\p{M}\p{N}]', unicode: true);

bool _isSpaceAt(String text, int index) => _whitespace.hasMatch(text[index]);

/// Character range of the whitespace-delimited token containing [offset].
///
/// Leading/trailing punctuation („ “ , . ! ? : ; …) stays part of the token so
/// it is focused together with its word. Returns null when [offset] is on
/// whitespace, out of range, or on a token without any letter or digit
/// (for example a standalone dash).
TextRange? wordFocusRangeAt(String text, int offset) {
  if (offset < 0 || offset >= text.length || _isSpaceAt(text, offset)) {
    return null;
  }

  var start = offset;
  while (start > 0 && !_isSpaceAt(text, start - 1)) {
    start--;
  }
  var end = offset + 1;
  while (end < text.length && !_isSpaceAt(text, end)) {
    end++;
  }

  if (!_wordCharacter.hasMatch(text.substring(start, end))) {
    return null;
  }
  return TextRange(start: start, end: end);
}

/// Resolves a caret offset from text hit-testing to a word range.
///
/// A tap on the right half of a word's last character yields a caret *after*
/// it, so the character before the caret is tried as well.
TextRange? wordFocusRangeForCaret(String text, int caretOffset) {
  return wordFocusRangeAt(text, caretOffset) ??
      wordFocusRangeAt(text, caretOffset - 1);
}

/// Tapping the focused word again clears focus; any other word moves it.
TextRange? toggleWordFocus(TextRange? current, TextRange tapped) {
  return current == tapped ? null : tapped;
}

/// Whether [range] is a usable, non-empty selection inside [text].
bool isWordFocusRangeValid(TextRange? range, String text) {
  return range != null &&
      range.isValid &&
      !range.isCollapsed &&
      range.end <= text.length;
}

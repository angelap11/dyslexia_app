import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../core/theme.dart';
import '../../core/word_focus_selection.dart';

/// Read-only text with «Фокус на збор»: the selected word stays sharp, the
/// rest of the paragraph is blurred.
///
/// Every layer renders the same [Text] with the same [style] and constraints,
/// so line breaks and glyph positions are identical. Word geometry comes from
/// the sharp layer's [RenderParagraph], which is also the only layer exposed
/// to screen readers.
class WordFocusText extends StatefulWidget {
  final String text;
  final TextStyle? style;

  /// Focused word as character offsets into [text], or null for no focus.
  final TextRange? selection;
  final ValueChanged<TextRange?> onSelectionChanged;
  final double blurSigma;

  /// Opaque fill drawn under the focused word so blur from it and its
  /// neighbours does not show through. Defaults to the surface colour.
  final Color? backgroundColor;

  const WordFocusText({
    super.key,
    required this.text,
    required this.style,
    required this.selection,
    required this.onSelectionChanged,
    this.blurSigma = gentleBlurSigma,
    this.backgroundColor,
  });

  static const double gentleBlurSigma = 1.6;

  /// Extra touch slop around a word's boxes, in logical pixels.
  static const double hitSlop = 6.0;

  @override
  State<WordFocusText> createState() => WordFocusTextState();
}

class WordFocusTextState extends State<WordFocusText> {
  final GlobalKey _paragraphKey = GlobalKey();

  RenderParagraph? get _paragraph {
    final renderObject = _paragraphKey.currentContext?.findRenderObject();
    if (renderObject is RenderParagraph &&
        renderObject.attached &&
        renderObject.hasSize) {
      return renderObject;
    }
    return null;
  }

  TextRange? get _activeSelection {
    final selection = widget.selection;
    return isWordFocusRangeValid(selection, widget.text) ? selection : null;
  }

  List<Rect> _boxesFor(RenderParagraph paragraph, TextRange range) {
    return [
      for (final box in paragraph.getBoxesForSelection(
        TextSelection(baseOffset: range.start, extentOffset: range.end),
      ))
        box.toRect(),
    ];
  }

  /// Focus rectangles for the current selection in paragraph coordinates.
  List<Rect> _focusRects() {
    final selection = _activeSelection;
    final paragraph = _paragraph;
    if (selection == null || paragraph == null) return const [];
    return [
      for (final rect in _boxesFor(paragraph, selection))
        Rect.fromLTRB(
          rect.left - 3,
          rect.top - 2,
          rect.right + 3,
          rect.bottom + 2,
        ),
    ];
  }

  /// Toggles focus on the word under [globalPosition].
  ///
  /// Returns false when the position is not on a word (blank space,
  /// whitespace-only area or a standalone punctuation mark).
  bool handleTapAt(Offset globalPosition) {
    final paragraph = _paragraph;
    if (paragraph == null) return false;

    final local = paragraph.globalToLocal(globalPosition);
    final caret = paragraph.getPositionForOffset(local).offset;
    final range = wordFocusRangeForCaret(widget.text, caret);
    if (range == null) return false;

    final onWord = _boxesFor(
      paragraph,
      range,
    ).any((rect) => rect.inflate(WordFocusText.hitSlop).contains(local));
    if (!onWord) return false;

    widget.onSelectionChanged(toggleWordFocus(_activeSelection, range));
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final focused = _activeSelection != null;
    final isDark = context.isDark;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTapUp: (details) => handleTapAt(details.globalPosition),
      child: Stack(
        children: [
          if (focused)
            ExcludeSemantics(
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(
                  sigmaX: widget.blurSigma,
                  sigmaY: widget.blurSigma,
                  tileMode: TileMode.decal,
                ),
                child: RepaintBoundary(
                  child: Text(widget.text, style: widget.style),
                ),
              ),
            ),
          if (focused)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _WordFocusHighlightPainter(
                    rects: _focusRects,
                    cover: widget.backgroundColor ?? context.appSurface,
                    fill: AppColors.primary.withValues(
                      alpha: isDark ? 0.30 : 0.14,
                    ),
                    border: AppColors.primary.withValues(
                      alpha: isDark ? 0.65 : 0.45,
                    ),
                  ),
                ),
              ),
            ),
          ClipPath(
            clipper: focused ? _WordFocusClipper(_focusRects) : null,
            clipBehavior: focused ? Clip.antiAlias : Clip.none,
            child: Text(widget.text, key: _paragraphKey, style: widget.style),
          ),
        ],
      ),
    );
  }
}

class _WordFocusClipper extends CustomClipper<Path> {
  final List<Rect> Function() rects;

  _WordFocusClipper(this.rects);

  @override
  Path getClip(Size size) {
    final path = Path();
    for (final rect in rects()) {
      path.addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(6)));
    }
    return path;
  }

  // Keeps the sharp paragraph in the semantics tree at full size.
  @override
  Rect getApproximateClipRect(Size size) => Offset.zero & size;

  @override
  bool shouldReclip(covariant _WordFocusClipper oldClipper) => true;
}

class _WordFocusHighlightPainter extends CustomPainter {
  final List<Rect> Function() rects;
  final Color cover;
  final Color fill;
  final Color border;

  _WordFocusHighlightPainter({
    required this.rects,
    required this.cover,
    required this.fill,
    required this.border,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final coverPaint = Paint()..color = cover;
    final fillPaint = Paint()..color = fill;
    final borderPaint = Paint()
      ..color = border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (final rect in rects()) {
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6));
      canvas
        ..drawRRect(rrect, coverPaint)
        ..drawRRect(rrect, fillPaint)
        ..drawRRect(rrect.deflate(0.5), borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WordFocusHighlightPainter oldDelegate) => true;
}

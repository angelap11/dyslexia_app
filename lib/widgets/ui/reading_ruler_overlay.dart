import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_settings.dart';
import '../../core/theme.dart';
import '../../features/settings/provider.dart';

/// Exact rendered height of one text line for the reading ruler band.
///
/// Uses [TextPainter.preferredLineHeight] with the active [TextScaler] so the
/// band tracks font size / line-height settings (including dyslexia spacing).
double measureReadingRulerLineHeight({
  required TextStyle style,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  final painter = TextPainter(
    text: TextSpan(text: 'HgАј', style: style),
    textDirection: TextDirection.ltr,
    textScaler: textScaler,
    maxLines: 1,
    strutStyle: StrutStyle.fromTextStyle(
      style,
      forceStrutHeight: true,
      height: style.height,
    ),
  )..layout(maxWidth: double.infinity);

  final measured = painter.preferredLineHeight;
  if (measured > 0) {
    return measured;
  }
  return math.max(painter.height, 1.0);
}

/// Snaps a ruler top offset onto the text line grid.
double snapReadingRulerTop({
  required double top,
  required double lineHeight,
  required double maxTop,
  double contentTopInset = 0,
}) {
  if (lineHeight <= 0) {
    return top.clamp(0.0, maxTop);
  }
  final relative = top - contentTopInset;
  final index = (relative / lineHeight).round();
  final snapped = contentTopInset + index * lineHeight;
  return snapped.clamp(0.0, maxTop);
}

/// Extra bottom scroll extent so the last line can enter the reading band.
double readingRulerEndPadding({
  required double rulerHeight,
  required double containerHeight,
  double rulerTop = 0,
  double extraMargin = AppSpacing.xl,
}) {
  if (containerHeight <= 0 || rulerHeight <= 0) {
    return 0;
  }

  final minimum = rulerHeight + extraMargin;
  final toBandCenter = (containerHeight - rulerTop - rulerHeight / 2).clamp(
    0.0,
    containerHeight,
  );
  return math.max(minimum, toBandCenter);
}

/// [ScrollController] that can extend [maxScrollExtent] without adding a
/// visible spacer. Extra extent is applied only when the text already overflows.
class ReadingRulerScrollController extends ScrollController {
  ReadingRulerScrollController({double extraBottom = 0})
    : _extraBottom = extraBottom;

  double _extraBottom;

  double get extraBottom => _extraBottom;

  set extraBottom(double value) {
    final next = value < 0 ? 0.0 : value;
    if (_extraBottom == next) {
      return;
    }
    _extraBottom = next;
    for (final position in positions) {
      if (position is _ReadingRulerScrollPosition) {
        position.updateExtraBottom(next);
      }
    }
  }

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return _ReadingRulerScrollPosition(
      physics: physics,
      context: context,
      oldPosition: oldPosition,
      extraBottom: _extraBottom,
    );
  }
}

class _ReadingRulerScrollPosition extends ScrollPositionWithSingleContext {
  _ReadingRulerScrollPosition({
    required super.physics,
    required super.context,
    super.oldPosition,
    required double extraBottom,
  }) : _extraBottom = extraBottom;

  double _extraBottom;
  double _rawMinScrollExtent = 0;
  double _rawMaxScrollExtent = 0;
  bool _hasRawExtents = false;

  void updateExtraBottom(double value) {
    if (_extraBottom == value) {
      return;
    }
    _extraBottom = value;
    if (_hasRawExtents) {
      applyContentDimensions(_rawMinScrollExtent, _rawMaxScrollExtent);
    }
  }

  @override
  bool applyContentDimensions(double minScrollExtent, double maxScrollExtent) {
    _rawMinScrollExtent = minScrollExtent;
    _rawMaxScrollExtent = maxScrollExtent;
    _hasRawExtents = true;
    final extra = maxScrollExtent > 0.5 ? _extraBottom : 0.0;
    return super.applyContentDimensions(
      minScrollExtent,
      maxScrollExtent + extra,
    );
  }
}

/// Visual reading-ruler layers only — place above text in a [Stack].
///
/// Band height is derived from [textStyle] (+ ambient [TextScaler]), not a
/// fixed pixel setting, so exactly one rendered line is highlighted.
///
/// Drag UX: the *visible* band stays one line tall; the *hit* band is at least
/// [AppTouch.min] tall so children can grab it easily. Vertical drags on the
/// band move the ruler; touches outside pass through to the text ScrollView.
class ReadingRulerOverlay extends StatefulWidget {
  final bool enabled;
  final TextStyle textStyle;

  /// Top inset of the text inside the stack (scroll/content padding).
  final double contentTopInset;
  final double dimOpacity;
  final BorderRadius borderRadius;
  final ScrollController? scrollController;

  /// Receives taps on the ruler band, which would otherwise never reach the
  /// text underneath it (e.g. for word focus).
  final ValueChanged<Offset>? onTapThrough;

  /// Minimum vertical hit target (invisible padding around the band).
  /// Larger than [AppTouch.min] so children can drag without precision aiming.
  static const double minHitExtent = 64.0;

  /// Viewport edge zone that triggers gentle auto-scroll while dragging.
  static const double edgeAutoScrollZone = 56.0;

  const ReadingRulerOverlay({
    super.key,
    required this.enabled,
    required this.textStyle,
    this.contentTopInset = 0,
    this.dimOpacity = AppSettings.defaultReadingRulerDimOpacity,
    this.borderRadius = BorderRadius.zero,
    this.scrollController,
    this.onTapThrough,
  });

  @override
  State<ReadingRulerOverlay> createState() => _ReadingRulerOverlayState();
}

class _ReadingRulerOverlayState extends State<ReadingRulerOverlay> {
  /// Snapped resting position (line grid).
  double _rulerTop = 0;

  /// Live finger-follow position while dragging (unsnapped).
  double _dragTop = 0;
  bool _dragging = false;

  double _lastContainerHeight = 0;
  double _lastLineHeight = 0;

  Timer? _edgeScrollTimer;
  double _edgeScrollVelocity = 0;

  double get _displayTop => _dragging ? _dragTop : _rulerTop;

  @override
  void didUpdateWidget(covariant ReadingRulerOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) {
      // Keep the last resting line so showing the ruler again restores it.
      _stopEdgeScroll();
      if (_dragging) {
        _dragging = false;
        _dragTop = _rulerTop;
      }
      _scheduleExtraExtent(0);
      return;
    }

    if (oldWidget.textStyle != widget.textStyle ||
        oldWidget.contentTopInset != widget.contentTopInset) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _lastLineHeight <= 0 || _lastContainerHeight <= 0) {
          return;
        }
        final maxTop = _maxTopForHeight(_lastContainerHeight, _lastLineHeight);
        final snapped = snapReadingRulerTop(
          top: _rulerTop,
          lineHeight: _lastLineHeight,
          maxTop: maxTop,
          contentTopInset: widget.contentTopInset,
        );
        if (snapped != _rulerTop) {
          setState(() {
            _rulerTop = snapped;
            if (!_dragging) _dragTop = snapped;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _stopEdgeScroll();
    final controller = widget.scrollController;
    if (controller is ReadingRulerScrollController && controller.hasClients) {
      controller.extraBottom = 0;
    }
    super.dispose();
  }

  void _scheduleExtraExtent(double extra) {
    final controller = widget.scrollController;
    if (controller is! ReadingRulerScrollController) {
      return;
    }
    if (controller.extraBottom == extra) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controller.hasClients) {
        controller.extraBottom = extra;
      }
    });
  }

  void _updateEndScrollPadding({
    required double containerHeight,
    required double rulerTop,
    required double lineHeight,
  }) {
    if (!widget.enabled || containerHeight <= 0) {
      _scheduleExtraExtent(0);
      return;
    }

    _scheduleExtraExtent(
      readingRulerEndPadding(
        rulerHeight: lineHeight,
        containerHeight: containerHeight,
        rulerTop: rulerTop,
      ),
    );
  }

  double _maxTopForHeight(double containerHeight, double lineHeight) {
    return (containerHeight - lineHeight).clamp(0.0, double.infinity);
  }

  void _stopEdgeScroll() {
    _edgeScrollTimer?.cancel();
    _edgeScrollTimer = null;
    _edgeScrollVelocity = 0;
  }

  void _tickEdgeScroll(
    double maxTop,
    double lineHeight,
    double containerHeight,
  ) {
    if (!_dragging || !mounted || _edgeScrollVelocity == 0) {
      return;
    }
    final controller = widget.scrollController;
    if (controller == null || !controller.hasClients) {
      return;
    }

    final position = controller.position;
    final next = (position.pixels + _edgeScrollVelocity).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((next - position.pixels).abs() > 0.1) {
      controller.jumpTo(next);
    }

    // Keep the band usable near edges without jumping it out of the viewport.
    _updateEdgeScrollVelocity(containerHeight, lineHeight);
  }

  void _updateEdgeScrollVelocity(double containerHeight, double lineHeight) {
    const zone = ReadingRulerOverlay.edgeAutoScrollZone;
    const maxSpeed = 4.5; // px per ~16ms tick — gentle, not jumpy
    final center = _dragTop + lineHeight / 2;

    if (center < zone) {
      final t = (1.0 - (center / zone)).clamp(0.0, 1.0);
      _edgeScrollVelocity = -maxSpeed * t;
    } else if (center > containerHeight - zone) {
      final t = (1.0 - ((containerHeight - center) / zone)).clamp(0.0, 1.0);
      _edgeScrollVelocity = maxSpeed * t;
    } else {
      _edgeScrollVelocity = 0;
    }

    if (_edgeScrollVelocity.abs() > 0.05) {
      _edgeScrollTimer ??= Timer.periodic(const Duration(milliseconds: 16), (
        _,
      ) {
        if (!mounted) {
          _stopEdgeScroll();
          return;
        }
        final maxTop = _maxTopForHeight(_lastContainerHeight, _lastLineHeight);
        _tickEdgeScroll(maxTop, _lastLineHeight, _lastContainerHeight);
      });
    } else {
      _edgeScrollTimer?.cancel();
      _edgeScrollTimer = null;
    }
  }

  void _onDragStart(double maxTop) {
    _dragging = true;
    _dragTop = _rulerTop.clamp(0.0, maxTop);
  }

  void _onDragUpdate({
    required double deltaDy,
    required double maxTop,
    required double lineHeight,
    required double containerHeight,
  }) {
    final next = (_dragTop + deltaDy).clamp(0.0, maxTop);
    if (next == _dragTop && deltaDy.abs() < 0.01) {
      _updateEdgeScrollVelocity(containerHeight, lineHeight);
      return;
    }
    setState(() => _dragTop = next);
    _updateEdgeScrollVelocity(containerHeight, lineHeight);
  }

  void _onDragEnd({required double maxTop, required double lineHeight}) {
    _stopEdgeScroll();
    final snapped = snapReadingRulerTop(
      top: _dragTop,
      lineHeight: lineHeight,
      maxTop: maxTop,
      contentTopInset: widget.contentTopInset,
    );
    setState(() {
      _dragging = false;
      _rulerTop = snapped;
      _dragTop = snapped;
    });
  }

  Color _dimColor(BuildContext context) {
    final alpha = widget.dimOpacity.clamp(0.2, 0.75);
    if (context.isDark) {
      return Colors.black.withValues(alpha: alpha * 0.72);
    }
    return AppColors.textPrimaryLight.withValues(alpha: alpha * 0.38);
  }

  Color _bandFillColor(BuildContext context) {
    if (context.isDark) {
      return AppColors.primary.withValues(alpha: 0.12);
    }
    return AppColors.primary.withValues(alpha: 0.07);
  }

  Color _bandEdgeColor(BuildContext context) {
    return AppColors.primary.withValues(alpha: context.isDark ? 0.42 : 0.28);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return const SizedBox.shrink();
    }

    final textScaler = MediaQuery.textScalerOf(context);
    final lineHeight = measureReadingRulerLineHeight(
      style: widget.textStyle,
      textScaler: textScaler,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final containerHeight = _resolveContainerHeight(constraints);
        if (containerHeight <= 0) {
          return const SizedBox.shrink();
        }

        _lastContainerHeight = containerHeight;
        _lastLineHeight = lineHeight;

        if (_rulerTop == 0 && widget.contentTopInset > 0 && !_dragging) {
          final initial = snapReadingRulerTop(
            top: widget.contentTopInset,
            lineHeight: lineHeight,
            maxTop: _maxTopForHeight(containerHeight, lineHeight),
            contentTopInset: widget.contentTopInset,
          );
          if (initial != _rulerTop) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_dragging) {
                setState(() {
                  _rulerTop = initial;
                  _dragTop = initial;
                });
              }
            });
          }
        }

        if (containerHeight <= lineHeight) {
          _updateEndScrollPadding(
            containerHeight: containerHeight,
            rulerTop: 0,
            lineHeight: lineHeight,
          );
          return ClipRRect(
            borderRadius: widget.borderRadius,
            child: Material(
              type: MaterialType.transparency,
              child: SizedBox.expand(
                child: ColoredBox(color: _bandFillColor(context)),
              ),
            ),
          );
        }

        final maxTop = _maxTopForHeight(containerHeight, lineHeight);
        if (!_dragging && _rulerTop > maxTop) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_dragging) {
              setState(() {
                _rulerTop = maxTop;
                _dragTop = maxTop;
              });
            }
          });
        }

        final displayTop = _displayTop.clamp(0.0, maxTop);
        final restingTop = _dragging
            ? displayTop
            : snapReadingRulerTop(
                top: displayTop,
                lineHeight: lineHeight,
                maxTop: maxTop,
                contentTopInset: widget.contentTopInset,
              );

        _updateEndScrollPadding(
          containerHeight: containerHeight,
          rulerTop: restingTop,
          lineHeight: lineHeight,
        );

        final dimColor = _dimColor(context);
        final handleSize = math.min(44.0, math.max(28.0, lineHeight - 2));

        // Invisible hit padding so children don't need pixel-perfect aim.
        final hitPad = math.max(
          0.0,
          (ReadingRulerOverlay.minHitExtent - lineHeight) / 2,
        );
        final hitTop = (restingTop - hitPad).clamp(0.0, maxTop);
        final hitBottom = (restingTop + lineHeight + hitPad).clamp(
          0.0,
          containerHeight,
        );
        final hitHeight = math.max(lineHeight, hitBottom - hitTop);
        final visualOffsetInHit = restingTop - hitTop;

        return ClipRRect(
          borderRadius: widget.borderRadius,
          child: Material(
            type: MaterialType.transparency,
            child: SizedBox(
              height: containerHeight,
              width: constraints.maxWidth.isFinite
                  ? constraints.maxWidth
                  : null,
              child: Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.hardEdge,
                children: [
                  // Dim layers ignore pointers so text scrolling works outside
                  // the ruler hit band.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Column(
                        children: [
                          Container(height: restingTop, color: dimColor),
                          SizedBox(height: lineHeight),
                          Expanded(child: ColoredBox(color: dimColor)),
                        ],
                      ),
                    ),
                  ),
                  // Full-width vertical drag target (expanded hit, 1-line visual).
                  Positioned(
                    top: hitTop,
                    left: 0,
                    right: 0,
                    height: hitHeight,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: widget.onTapThrough == null
                          ? null
                          : (details) =>
                                widget.onTapThrough!(details.globalPosition),
                      onVerticalDragStart: (_) => _onDragStart(maxTop),
                      onVerticalDragUpdate: (details) {
                        _onDragUpdate(
                          deltaDy: details.delta.dy,
                          maxTop: maxTop,
                          lineHeight: lineHeight,
                          containerHeight: containerHeight,
                        );
                      },
                      onVerticalDragEnd: (_) {
                        _onDragEnd(maxTop: maxTop, lineHeight: lineHeight);
                      },
                      onVerticalDragCancel: () {
                        _onDragEnd(maxTop: maxTop, lineHeight: lineHeight);
                      },
                      child: Semantics(
                        label: 'Помести ја линијата за читање',
                        hint: 'Повлечи нагоре или надолу',
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned(
                              top: visualOffsetInHit,
                              left: 0,
                              right: 0,
                              height: lineHeight,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: _bandFillColor(context),
                                  border: Border(
                                    top: BorderSide(
                                      color: _bandEdgeColor(context),
                                      width: 1,
                                    ),
                                    bottom: BorderSide(
                                      color: _bandEdgeColor(context),
                                      width: 1,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              right: AppSpacing.xs,
                              top: visualOffsetInHit,
                              height: lineHeight,
                              child: Center(
                                child: _ReadingRulerGrip(
                                  handleHeight: handleSize,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  double _resolveContainerHeight(BoxConstraints constraints) {
    if (constraints.maxHeight.isFinite && constraints.maxHeight > 0) {
      return constraints.maxHeight;
    }
    if (constraints.minHeight.isFinite && constraints.minHeight > 0) {
      return constraints.minHeight;
    }
    return 0;
  }
}

/// Visual grip only — gestures are owned by the full-width band above.
class _ReadingRulerGrip extends StatelessWidget {
  final double handleHeight;

  const _ReadingRulerGrip({required this.handleHeight});

  @override
  Widget build(BuildContext context) {
    final h = handleHeight.clamp(24.0, 44.0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Material(
        color: context.appSurface.withValues(
          alpha: context.isDark ? 0.88 : 0.92,
        ),
        elevation: 1,
        shadowColor: Colors.black.withValues(
          alpha: context.isDark ? 0.25 : 0.08,
        ),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          width: 18,
          height: h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: AppColors.primary.withValues(
                alpha: context.isDark ? 0.32 : 0.22,
              ),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _GripDot(color: AppColors.primary.withValues(alpha: 0.55)),
              SizedBox(height: h > 32 ? 3 : 2),
              _GripDot(color: AppColors.primary.withValues(alpha: 0.75)),
              SizedBox(height: h > 32 ? 3 : 2),
              _GripDot(color: AppColors.primary.withValues(alpha: 0.55)),
            ],
          ),
        ),
      ),
    );
  }
}

class _GripDot extends StatelessWidget {
  final Color color;

  const _GripDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      height: 4,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// Toggle and optional dimming for reading screens.
class ReadingRulerControls extends StatelessWidget {
  final bool showAdjustments;

  const ReadingRulerControls({super.key, this.showAdjustments = true});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.appSurfaceMuted.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: context.appBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FilterChip(
            label: const Text('Линијар'),
            selected: settings.readingRulerEnabled,
            onSelected: settings.setReadingRulerEnabled,
            avatar: Icon(
              settings.readingRulerEnabled
                  ? Icons.horizontal_rule_rounded
                  : Icons.horizontal_rule_outlined,
              size: 18,
              color: settings.readingRulerEnabled
                  ? AppColors.primary
                  : context.appTextSecondary,
            ),
            selectedColor: AppColors.primary.withValues(alpha: 0.15),
            checkmarkColor: AppColors.primary,
            labelStyle: TextStyle(
              fontWeight: FontWeight.w700,
              color: settings.readingRulerEnabled
                  ? AppColors.primary
                  : context.appTextPrimary,
            ),
            side: BorderSide(
              color: settings.readingRulerEnabled
                  ? AppColors.primary.withValues(alpha: 0.45)
                  : context.appBorder,
            ),
          ),
          if (showAdjustments && settings.readingRulerEnabled) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Icon(
                  Icons.opacity_rounded,
                  size: 18,
                  color: context.appTextSecondary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 7,
                      ),
                    ),
                    child: Slider(
                      value: settings.readingRulerDimOpacity,
                      min: 0.2,
                      max: 0.75,
                      divisions: 11,
                      label: 'Затемнување',
                      onChanged: settings.setReadingRulerDimOpacity,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

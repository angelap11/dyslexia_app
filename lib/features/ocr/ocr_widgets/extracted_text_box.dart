import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/accessibility.dart';
import '../../../core/app_settings.dart';
import '../../../core/theme.dart';
import '../../../features/settings/provider.dart';
import '../../../features/settings/settings_widgets/settings_controls.dart';
import '../../../widgets/dyslexia_text.dart';
import '../../../widgets/ui/reading_ruler_overlay.dart';
import '../../../widgets/ui/text_toolbar_action.dart';
import '../../../widgets/ui/word_focus_controls.dart';
import '../../../widgets/ui/word_focus_text.dart';

class ExtractedTextBox extends StatefulWidget {
  final String text;
  final bool isLoading;
  final bool dyslexiaMode;
  final bool expand;
  final bool inset;
  final bool isEditing;
  final TextEditingController? editController;
  final VoidCallback? onToggleEdit;
  final VoidCallback? onCopy;
  final VoidCallback? onSave;
  final VoidCallback? onClear;
  final bool saved;
  final bool saving;

  /// Shown next to the word count, e.g. the sync state of the saved item.
  final Widget? saveStatus;
  final bool isReading;
  final VoidCallback? onPlay;
  final VoidCallback? onStop;
  final String cardTitle;

  /// Screen-local «Фокус на збор» state. The switch is shown only when
  /// [onWordFocusChanged] is provided.
  final bool wordFocusOn;
  final ValueChanged<bool>? onWordFocusChanged;

  const ExtractedTextBox({
    super.key,
    required this.text,
    required this.isLoading,
    required this.dyslexiaMode,
    this.expand = false,
    this.inset = true,
    this.isEditing = false,
    this.editController,
    this.onToggleEdit,
    this.onCopy,
    this.onSave,
    this.onClear,
    this.saved = false,
    this.saving = false,
    this.saveStatus,
    this.isReading = false,
    this.onPlay,
    this.onStop,
    this.cardTitle = 'Текст',
    this.wordFocusOn = false,
    this.onWordFocusChanged,
  });

  @override
  State<ExtractedTextBox> createState() => _ExtractedTextBoxState();
}

class _ExtractedTextBoxState extends State<ExtractedTextBox> {
  final ReadingRulerScrollController _scrollController =
      ReadingRulerScrollController();
  final GlobalKey<WordFocusTextState> _wordFocusKey = GlobalKey();

  /// Word focused via «Фокус на збор», as offsets into [ExtractedTextBox.text].
  TextRange? _focusedWord;

  @override
  void didUpdateWidget(covariant ExtractedTextBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        widget.isEditing ||
        !widget.wordFocusOn) {
      _focusedWord = null;
    }
  }

  void _clearWordFocus() {
    if (_focusedWord == null) return;
    setState(() => _focusedWord = null);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  int get _wordCount {
    final text = widget.text.trim();
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).length;
  }

  String _speedWord(double rate) {
    if (rate < 0.4) return 'Побавно';
    if (rate > 0.65) return 'Побрзо';
    return 'Нормално';
  }

  String _speedChip(double rate) {
    // Compact label for toolbar (not a large vertical section).
    return '${rate.toStringAsFixed(1)}x';
  }

  Future<void> _openSpeed(BuildContext context, SettingsProvider settings) {
    return showSettingsSliderSheet(
      context: context,
      title: 'Брзина',
      icon: Icons.speed_rounded,
      color: AppColors.lavender,
      value: settings.speechRate,
      min: 0.1,
      max: 1.0,
      divisions: 9,
      valueLabel: _speedWord,
      onChanged: settings.setSpeechRate,
      lowLabel: 'Побавно',
      highLabel: 'Побрзо',
    );
  }

  Future<void> _openFontSize(BuildContext context, SettingsProvider settings) {
    final minFont = AppSettings.baseFontSize * AppSettings.minFontScale;
    final maxFont = AppSettings.baseFontSize * AppSettings.maxFontScale;
    return showSettingsSliderSheet(
      context: context,
      title: 'Големина',
      icon: Icons.format_size_rounded,
      color: AppColors.mint,
      value: settings.fontSize,
      min: minFont,
      max: maxFont,
      divisions: 12,
      valueLabel: (v) {
        if (v < 16) return 'Мала';
        if (v < 20) return 'Средна';
        return 'Голема';
      },
      onChanged: settings.setFontSize,
      lowLabel: 'A',
      highLabel: 'A',
      lowLabelSize: 14,
      highLabelSize: 22,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading || widget.text.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final settings = context.watch<SettingsProvider>();
    final readingStyle = context.readingTextStyle(
      useDyslexiaFont: widget.dyslexiaMode,
    );
    final showRuler = settings.readingRulerEnabled && !widget.isEditing;
    final wordFocusOn = widget.wordFocusOn && !widget.isEditing;
    if (!wordFocusOn) _focusedWord = null;

    final Widget readOnlyText;
    if (wordFocusOn) {
      readOnlyText = WordFocusText(
        key: _wordFocusKey,
        text: widget.text,
        style: widget.dyslexiaMode
            ? DyslexiaText.styleFor(readingStyle)
            : readingStyle,
        selection: _focusedWord,
        backgroundColor: context.appSurface,
        onSelectionChanged: (range) => setState(() => _focusedWord = range),
      );
    } else if (widget.dyslexiaMode) {
      readOnlyText = DyslexiaText(widget.text, style: readingStyle);
    } else {
      readOnlyText = Text(widget.text, style: readingStyle);
    }

    final textBody = widget.isEditing && widget.editController != null
        ? TextField(
            controller: widget.editController,
            scrollController: _scrollController,
            expands: widget.expand,
            maxLines: widget.expand ? null : null,
            minLines: widget.expand ? null : 8,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            textAlignVertical: TextAlignVertical.top,
            style: readingStyle,
            decoration: InputDecoration(
              border: InputBorder.none,
              filled: true,
              fillColor: Colors.transparent,
              contentPadding: EdgeInsets.zero,
              isDense: true,
              hintText: 'Уреди го текстот...',
              hintStyle: TextStyle(
                color: context.appTextSecondary.withValues(alpha: 0.6),
              ),
            ),
          )
        : readOnlyText;

    final readingSurface = ClipRRect(
      borderRadius: const BorderRadius.vertical(
        bottom: Radius.circular(AppRadius.hero),
      ),
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.hardEdge,
        children: [
          if (widget.isEditing)
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: textBody,
              ),
            )
          else
            SingleChildScrollView(
              controller: _scrollController,
              padding: EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                wordFocusOn ? AppSpacing.xxxl + AppTouch.min : AppSpacing.xxxl,
              ),
              child: textBody,
            ),
          ReadingRulerOverlay(
            enabled: showRuler,
            textStyle: readingStyle,
            contentTopInset: AppSpacing.lg,
            dimOpacity: settings.readingRulerDimOpacity,
            scrollController: _scrollController,
            onTapThrough: wordFocusOn
                ? (position) =>
                      _wordFocusKey.currentState?.handleTapAt(position)
                : null,
          ),
          if (wordFocusOn && _focusedWord != null)
            Positioned(
              right: AppSpacing.md,
              bottom: AppSpacing.md,
              child: WordFocusClearButton(onPressed: _clearWordFocus),
            ),
        ],
      ),
    );

    final editorCard = Container(
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(AppRadius.hero),
        border: Border.all(color: context.appBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.25 : 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CompactToolbar(
            title: widget.isEditing ? 'Уреди' : widget.cardTitle,
            subtitle: widget.isEditing ? null : '$_wordCount',
            isReading: widget.isReading,
            isEditing: widget.isEditing,
            saved: widget.saved,
            saving: widget.saving,
            status: widget.isEditing ? null : widget.saveStatus,
            speedLabel: _speedChip(settings.speechRate),
            onPlay: widget.onPlay,
            onStop: widget.onStop,
            onToggleEdit: widget.onToggleEdit,
            onCopy: widget.onCopy,
            onSave: widget.onSave,
            onClear: widget.onClear,
            onSpeed: () => _openSpeed(context, settings),
            onFontSize: () => _openFontSize(context, settings),
            dyslexiaOn: settings.dyslexiaFont,
            onToggleDyslexia: () =>
                settings.setDyslexiaFont(!settings.dyslexiaFont),
            rulerOn: settings.readingRulerEnabled,
            onToggleRuler: () =>
                settings.setReadingRulerEnabled(!settings.readingRulerEnabled),
          ),
          if (widget.onWordFocusChanged != null)
            WordFocusSwitchRow(
              value: wordFocusOn,
              onChanged: widget.onWordFocusChanged,
            ),
          if (widget.expand)
            Expanded(child: readingSurface)
          else
            SizedBox(height: 320, child: readingSurface),
        ],
      ),
    );

    return Padding(
      padding: widget.inset ? EdgeInsets.zero : EdgeInsets.zero,
      child: editorCard,
    );
  }
}

/// Compact card header: primary TTS/edit icons + overflow for secondary actions.
class _CompactToolbar extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool isReading;
  final bool isEditing;
  final bool saved;
  final bool saving;
  final Widget? status;
  final String speedLabel;
  final VoidCallback? onPlay;
  final VoidCallback? onStop;
  final VoidCallback? onToggleEdit;
  final VoidCallback? onCopy;
  final VoidCallback? onSave;
  final VoidCallback? onClear;
  final VoidCallback onSpeed;
  final VoidCallback onFontSize;
  final bool dyslexiaOn;
  final VoidCallback onToggleDyslexia;
  final bool rulerOn;
  final VoidCallback onToggleRuler;

  const _CompactToolbar({
    required this.title,
    required this.subtitle,
    required this.isReading,
    required this.isEditing,
    required this.saved,
    required this.saving,
    required this.status,
    required this.speedLabel,
    required this.onPlay,
    required this.onStop,
    required this.onToggleEdit,
    required this.onCopy,
    required this.onSave,
    required this.onClear,
    required this.onSpeed,
    required this.onFontSize,
    required this.dyslexiaOn,
    required this.onToggleDyslexia,
    required this.rulerOn,
    required this.onToggleRuler,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.mint.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.hero),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Keep Play / Stop / Edit visible; secondary actions → overflow on
          // narrow widths so the toolbar never horizontally overflows.
          final showSecondaryInline = constraints.maxWidth >= 420;

          return Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle != null)
                      Row(
                        children: [
                          Text(
                            subtitle!,
                            maxLines: 1,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (status != null) ...[
                            const SizedBox(width: AppSpacing.sm),
                            Flexible(child: status!),
                          ],
                        ],
                      ),
                  ],
                ),
              ),
              if (onPlay != null)
                TextToolbarAction(
                  icon: isReading
                      ? Icons.graphic_eq_rounded
                      : Icons.play_arrow_rounded,
                  tooltip: isReading ? 'Слуша' : 'Слушај',
                  onTap: onPlay!,
                  active: isReading,
                  color: AppColors.primary,
                ),
              if (onStop != null)
                TextToolbarAction(
                  icon: Icons.stop_rounded,
                  tooltip: 'Стоп',
                  onTap: onStop!,
                ),
              if (showSecondaryInline) ...[
                TextToolbarAction(
                  icon: Icons.speed_rounded,
                  tooltip: 'Брзина на гласот ($speedLabel)',
                  onTap: onSpeed,
                  color: AppColors.lavender,
                ),
                if (onCopy != null)
                  TextToolbarAction(
                    icon: Icons.copy_rounded,
                    tooltip: 'Копирај',
                    onTap: onCopy!,
                  ),
              ],
              if (onSave != null)
                TextToolbarAction(
                  key: const ValueKey('save-text-action'),
                  icon: saved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_add_outlined,
                  tooltip: saved ? 'Зачувано' : 'Зачувај',
                  onTap: saving ? null : onSave,
                  active: saved,
                ),
              if (onToggleEdit != null)
                TextToolbarAction(
                  icon: isEditing ? Icons.check_rounded : Icons.edit_rounded,
                  tooltip: isEditing ? 'Готово' : 'Уреди',
                  onTap: onToggleEdit!,
                  active: isEditing,
                ),
              if (showSecondaryInline && onClear != null)
                TextToolbarAction(
                  icon: Icons.delete_outline_rounded,
                  tooltip: 'Исчисти',
                  onTap: onClear!,
                ),
              PopupMenuButton<_ToolbarMenuAction>(
                tooltip: 'Повеќе',
                padding: EdgeInsets.zero,
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: context.appTextSecondary,
                  size: 22,
                ),
                onSelected: (action) {
                  switch (action) {
                    case _ToolbarMenuAction.speed:
                      onSpeed();
                    case _ToolbarMenuAction.copy:
                      onCopy?.call();
                    case _ToolbarMenuAction.clear:
                      onClear?.call();
                    case _ToolbarMenuAction.dyslexia:
                      onToggleDyslexia();
                    case _ToolbarMenuAction.ruler:
                      onToggleRuler();
                    case _ToolbarMenuAction.fontSize:
                      onFontSize();
                  }
                },
                itemBuilder: (context) => [
                  if (!showSecondaryInline)
                    PopupMenuItem(
                      value: _ToolbarMenuAction.speed,
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.speed_rounded),
                        title: Text('Брзина ($speedLabel)'),
                      ),
                    ),
                  if (!showSecondaryInline && onCopy != null)
                    const PopupMenuItem(
                      value: _ToolbarMenuAction.copy,
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.copy_rounded),
                        title: Text('Копирај'),
                      ),
                    ),
                  if (!showSecondaryInline && onClear != null)
                    const PopupMenuItem(
                      value: _ToolbarMenuAction.clear,
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.delete_outline_rounded),
                        title: Text('Исчисти'),
                      ),
                    ),
                  PopupMenuItem(
                    value: _ToolbarMenuAction.dyslexia,
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.font_download_rounded,
                        color: dyslexiaOn ? AppColors.coral : null,
                      ),
                      title: Text(
                        dyslexiaOn ? 'Dyslexia фонт (вкл.)' : 'Dyslexia фонт',
                      ),
                    ),
                  ),
                  PopupMenuItem(
                    value: _ToolbarMenuAction.ruler,
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.horizontal_rule_rounded,
                        color: rulerOn ? AppColors.primary : null,
                      ),
                      title: Text(
                        rulerOn ? 'Линијар (вкл.)' : 'Линијар за читање',
                      ),
                    ),
                  ),
                  const PopupMenuItem(
                    value: _ToolbarMenuAction.fontSize,
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.format_size_rounded),
                      title: Text('Големина'),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

enum _ToolbarMenuAction { speed, copy, clear, dyslexia, ruler, fontSize }

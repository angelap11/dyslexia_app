import 'package:dyslexia_app/features/statistics/stats_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../settings/provider.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/ui/decorative_background.dart';
import '../../widgets/ui/home_layout.dart';
import '../../widgets/ui/listen_text_toolbar.dart';
import '../../widgets/ui/reading_controls.dart';
import '../../widgets/ui/reading_ruler_overlay.dart';
import '../../widgets/ui/word_focus_controls.dart';
import '../../widgets/ui/word_focus_text.dart';
import '../../core/accessibility.dart';
import '../../core/keyboard.dart';
import '../../core/theme.dart';

import 'tts_service.dart';
import '../home/home_screen.dart';
import '../ocr/ocr_screen.dart';
import '../profile/profile_screen.dart';
import '../settings/settings_screen.dart';
import '../history/saved_text.dart';
import '../history/widgets/save_text_flow.dart';
import '../simplify/text_simplification_service.dart';
import '../simplify/widgets/simplify_text_bar.dart';

class TtsScreen extends StatefulWidget {
  @visibleForTesting
  final TtsService? ttsService;

  /// Saved History item to show; both of its versions stay available.
  final SavedText? initialText;

  const TtsScreen({super.key, this.ttsService, this.initialText});

  @override
  State<TtsScreen> createState() => _TtsScreenState();
}

class _TtsScreenState extends State<TtsScreen> {
  late final TtsService _tts;
  final StatsService _statsService = StatsService();
  final TextSimplificationService _simplifyService =
      TextSimplificationService();

  final TextEditingController _controller = TextEditingController();
  final FocusNode _editorFocus = FocusNode();
  final ReadingRulerScrollController _textScrollController =
      ReadingRulerScrollController();

  bool _isReading = false;
  bool _keyboardWasOpen = false;
  bool _isSimplifying = false;
  bool _showSimplified = false;
  String _originalText = '';
  String? _simplifiedText;

  /// «Фокус на збор» for this screen only; never persisted. When on, the
  /// controller text is shown read-only in [WordFocusText].
  bool _wordFocusOn = false;
  final GlobalKey<WordFocusTextState> _wordFocusKey = GlobalKey();
  TextRange? _focusedWord;

  /// Text [_focusedWord] was selected in; any other text invalidates it.
  String _focusedWordText = '';

  /// What the current text was saved as in History.
  final SavedTextDraft _draft = SavedTextDraft();
  SavedTextSource _textSource = SavedTextSource.listen;

  bool get _isSaved {
    final simplified = _showSimplified ? _controller.text : _simplifiedText;
    final original = _showSimplified ? _originalText : _controller.text;
    return _draft.isSavedAs(original, simplified);
  }

  bool get _hasText => _controller.text.trim().isNotEmpty;

  TextRange? get _activeFocusedWord =>
      _focusedWordText == _controller.text ? _focusedWord : null;

  bool get _hasSimplified =>
      _simplifiedText != null && _simplifiedText!.trim().isNotEmpty;

  String get _toolbarTitle {
    if (!_hasSimplified) return 'Текст';
    return _showSimplified ? 'Поедноставен текст' : 'Оригинален текст';
  }

  int get _words {
    final text = _controller.text.trim();
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).length;
  }

  @override
  void initState() {
    super.initState();
    _tts = widget.ttsService ?? TtsService();
    final initial = widget.initialText;
    if (initial != null) {
      _originalText = initial.originalText;
      _simplifiedText = initial.hasSimplified ? initial.simplifiedText : null;
      _textSource = initial.source;
      _controller.text = initial.originalText;
      _draft.attach(initial);
    }
  }

  @override
  void dispose() {
    _editorFocus.dispose();
    _tts.stop();
    _tts.dispose();
    _simplifyService.dispose();
    _textScrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// When IME dismisses, drop focus so we do not treat "focused" as editing.
  void _syncFocusAfterKeyboard(bool keyboardOpen) {
    if (_keyboardWasOpen && !keyboardOpen && _editorFocus.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (!isKeyboardVisible(context) && _editorFocus.hasFocus) {
          _editorFocus.unfocus();
        }
      });
    }
    _keyboardWasOpen = keyboardOpen;
  }

  Future<void> _start(double speechRate) async {
    final text = _controller.text.trim();

    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Прво напиши или залепи текст.')),
      );
      return;
    }

    _editorFocus.unfocus();
    setState(() => _isReading = true);
    try {
      await _tts.setSpeechRate(speechRate);
      await _tts.speak(text);
      await _statsService.incrementTTS();
    } finally {
      if (mounted) setState(() => _isReading = false);
    }
  }

  Future<void> _stop() async {
    await _tts.stop();
    if (mounted) setState(() => _isReading = false);
  }

  Future<void> _copyText() async {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Текстот е копиран')));
  }

  Future<void> _changeSpeed(SettingsProvider settings) async {
    await showSpeechRatePicker(context: context, settings: settings);
    if (!mounted) return;
    await _tts.setSpeechRate(settings.speechRate);
  }

  Future<void> _confirmClear() async {
    if (!_hasText) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Избриши текст'),
        content: const Text('Да го избришеме текстот?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Откажи'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Избриши'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _clearText();
  }

  Future<void> _clearText() async {
    if (_isReading) {
      await _stop();
    }
    _tts.resetProgress();
    _controller.clear();
    _originalText = '';
    _simplifiedText = null;
    _showSimplified = false;
    _wordFocusOn = false;
    _focusedWord = null;
    _draft.reset();
    _textSource = SavedTextSource.listen;
    if (_textScrollController.hasClients) {
      _textScrollController.jumpTo(0);
    }
    if (mounted) setState(() {});
  }

  Future<void> _saveText() async {
    _persistActiveBucket();
    await saveTextToHistory(
      context: context,
      draft: _draft,
      source: _textSource,
      originalText: _originalText,
      simplifiedText: _simplifiedText,
      onStateChanged: () {
        if (mounted) setState(() {});
      },
    );
  }

  void _persistActiveBucket() {
    if (_showSimplified) {
      _simplifiedText = _controller.text;
    } else {
      _originalText = _controller.text;
    }
  }

  void _setControllerText(String text) {
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _onShowingSimplifiedChanged(bool showSimplified) {
    if (showSimplified == _showSimplified) return;
    _persistActiveBucket();
    _showSimplified = showSimplified;
    _setControllerText(
      showSimplified ? (_simplifiedText ?? '') : _originalText,
    );
    _tts.resetProgress();
    setState(() {});
  }

  Future<void> _simplifyText() async {
    _persistActiveBucket();
    final source =
        (_originalText.trim().isNotEmpty ? _originalText : _controller.text)
            .trim();

    if (source.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Прво напиши или залепи текст.')),
      );
      return;
    }

    _originalText = source;
    _editorFocus.unfocus();
    setState(() => _isSimplifying = true);

    try {
      final result = await _simplifyService.simplify(source);
      if (!mounted) return;
      setState(() {
        _simplifiedText = result.simplifiedText;
        _showSimplified = true;
        _isSimplifying = false;
        _setControllerText(result.simplifiedText);
      });
      _tts.resetProgress();
      if (result.usedMock) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'DEMO режим: поедноставувањето е локално (нема backend URL).',
            ),
          ),
        );
      }
    } on TextSimplificationException catch (e) {
      if (!mounted) return;
      setState(() => _isSimplifying = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSimplifying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Поедноставувањето не успеа. Обиди се повторно.'),
        ),
      );
    }
  }

  void _onTextChanged(String _) {
    _tts.resetProgress();
    if (!_showSimplified) {
      _originalText = _controller.text;
    } else {
      _simplifiedText = _controller.text;
    }
    setState(() {});
  }

  /// Switches between the editor and the read-only word-focus view. The
  /// controller text is never modified here.
  Future<void> _setWordFocus(bool on) async {
    if (on == _wordFocusOn || (on && !_hasText)) return;
    if (_isReading) await _stop();
    if (!mounted) return;
    if (on) _editorFocus.unfocus();
    setState(() {
      _wordFocusOn = on;
      _focusedWord = null;
    });
  }

  Future<void> _editText() async {
    await _setWordFocus(false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_wordFocusOn) _editorFocus.requestFocus();
    });
  }

  void _onFocusedWordChanged(TextRange? range) {
    setState(() {
      _focusedWord = range;
      _focusedWordText = _controller.text;
    });
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final hasText = _hasText;
    final readingMode = _wordFocusOn && hasText;
    final focusedWord = readingMode ? _activeFocusedWord : null;
    // Chrome (nav / Play-Stop / toolbar) follows real IME visibility only —
    // not FocusNode.hasFocus, which can stay true after keyboard dismiss.
    final isKeyboardVisibleNow = isKeyboardVisible(context);
    _syncFocusAfterKeyboard(isKeyboardVisibleNow);

    return Scaffold(
      backgroundColor: context.appBackground,
      resizeToAvoidBottomInset: true,
      bottomNavigationBar: isKeyboardVisibleNow
          ? null
          : AppBottomNav(
              currentIndex: 1,
              onHomeTap: () => _open(context, const HomeScreen()),
              onReadTap: () {},
              onScanTap: () => _open(context, const OcrScreen()),
              onProfileTap: () => _open(context, const ProfileScreen()),
              onSettingsTap: () => _open(context, const SettingsScreen()),
            ),
      body: DecorativeBackground(
        child: SafeArea(
          bottom: isKeyboardVisibleNow,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final pad = HomeLayout.horizontalPadding(width);
              final tall = constraints.maxHeight > 640;
              final contentInset = isKeyboardVisibleNow
                  ? AppSpacing.lg
                  : (tall ? AppSpacing.xxl : AppSpacing.xl);

              return Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      pad,
                      isKeyboardVisibleNow ? AppSpacing.sm : AppSpacing.lg,
                      pad,
                      AppSpacing.sm,
                    ),
                    child: HomeLayout.constrain(
                      screenWidth: width,
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.lavender.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: const Icon(
                              Icons.menu_book_rounded,
                              color: AppColors.lavender,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              'Слушај текст',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          if (!isKeyboardVisibleNow)
                            FilterChip(
                              label: const Text('Линијар'),
                              selected: settings.readingRulerEnabled,
                              onSelected: settings.setReadingRulerEnabled,
                              visualDensity: VisualDensity.compact,
                              avatar: Icon(
                                Icons.horizontal_rule_rounded,
                                size: 18,
                                color: settings.readingRulerEnabled
                                    ? AppColors.primary
                                    : context.appTextSecondary,
                              ),
                              selectedColor: AppColors.primary.withValues(
                                alpha: 0.15,
                              ),
                              checkmarkColor: AppColors.primary,
                            ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        pad,
                        0,
                        pad,
                        isKeyboardVisibleNow ? AppSpacing.sm : AppSpacing.md,
                      ),
                      child: HomeLayout.constrain(
                        screenWidth: width,
                        maxWidth: 720,
                        child: Column(
                          children: [
                            Expanded(
                              child: Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: context.appSurface,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.hero,
                                  ),
                                  border: Border.all(color: context.appBorder),
                                  boxShadow: context.highContrast
                                      ? AppElevation.none
                                      : AppElevation.soft(context),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.hero,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      if (hasText && !isKeyboardVisibleNow)
                                        ListenTextToolbar(
                                          title: _toolbarTitle,
                                          wordCount: _words,
                                          speedLabel: speechRateLabel(
                                            settings.speechRate,
                                          ),
                                          onCopy: _copyText,
                                          onSpeed: () => _changeSpeed(settings),
                                          onClear: _confirmClear,
                                          onSave: _saveText,
                                          saved: _isSaved,
                                          saving: _draft.saving,
                                          status: _isSaved
                                              ? SavedTextStatusLabel(
                                                  id: _draft.savedId,
                                                )
                                              : null,
                                        ),
                                      WordFocusSwitchRow(
                                        value: readingMode,
                                        onChanged: hasText
                                            ? _setWordFocus
                                            : null,
                                        hint: hasText
                                            ? null
                                            : 'Внеси или залепи текст за да користиш фокус на збор.',
                                        action: readingMode
                                            ? TextButton.icon(
                                                onPressed: _editText,
                                                icon: const Icon(
                                                  Icons.edit_rounded,
                                                  size: 20,
                                                ),
                                                label: const Text(
                                                  'Уреди текст',
                                                ),
                                                style: TextButton.styleFrom(
                                                  foregroundColor:
                                                      AppColors.primary,
                                                  minimumSize: const Size(
                                                    AppTouch.min,
                                                    AppTouch.min,
                                                  ),
                                                ),
                                              )
                                            : null,
                                      ),
                                      Expanded(
                                        child: Stack(
                                          fit: StackFit.expand,
                                          clipBehavior: Clip.hardEdge,
                                          children: [
                                            if (readingMode)
                                              SingleChildScrollView(
                                                controller:
                                                    _textScrollController,
                                                padding: EdgeInsets.fromLTRB(
                                                  contentInset,
                                                  contentInset,
                                                  contentInset,
                                                  contentInset +
                                                      AppTouch.min +
                                                      AppSpacing.md,
                                                ),
                                                child: WordFocusText(
                                                  key: _wordFocusKey,
                                                  text: _controller.text,
                                                  style: context
                                                      .readingTextStyle(),
                                                  selection: focusedWord,
                                                  backgroundColor:
                                                      context.appSurface,
                                                  onSelectionChanged:
                                                      _onFocusedWordChanged,
                                                ),
                                              )
                                            else
                                              TextField(
                                                controller: _controller,
                                                focusNode: _editorFocus,
                                                scrollController:
                                                    _textScrollController,
                                                onChanged: _onTextChanged,
                                                expands: true,
                                                maxLines: null,
                                                minLines: null,
                                                textAlignVertical:
                                                    TextAlignVertical.top,
                                                keyboardType:
                                                    TextInputType.multiline,
                                                textInputAction:
                                                    TextInputAction.newline,
                                                style: context
                                                    .readingTextStyle(),
                                                decoration: InputDecoration(
                                                  border: InputBorder.none,
                                                  filled: true,
                                                  fillColor: Colors.transparent,
                                                  contentPadding:
                                                      EdgeInsets.all(
                                                        contentInset,
                                                      ),
                                                  hintText: hasText
                                                      ? null
                                                      : 'Што сакаш да слушаш?\nНапиши или залепи текст.',
                                                  hintMaxLines: 3,
                                                  hintStyle: TextStyle(
                                                    color: context
                                                        .appTextSecondary
                                                        .withValues(alpha: 0.6),
                                                    height: 1.35,
                                                  ),
                                                ),
                                              ),
                                            if (!isKeyboardVisibleNow)
                                              ReadingRulerOverlay(
                                                enabled: settings
                                                    .readingRulerEnabled,
                                                textStyle: context
                                                    .readingTextStyle(),
                                                contentTopInset: contentInset,
                                                dimOpacity: settings
                                                    .readingRulerDimOpacity,
                                                scrollController:
                                                    _textScrollController,
                                                onTapThrough: readingMode
                                                    ? (position) =>
                                                          _wordFocusKey
                                                              .currentState
                                                              ?.handleTapAt(
                                                                position,
                                                              )
                                                    : null,
                                              ),
                                            if (focusedWord != null)
                                              Positioned(
                                                right: AppSpacing.md,
                                                bottom: AppSpacing.md,
                                                child: WordFocusClearButton(
                                                  onPressed: () =>
                                                      _onFocusedWordChanged(
                                                        null,
                                                      ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (!isKeyboardVisibleNow) ...[
                              const SizedBox(height: AppSpacing.md),
                              SimplifyTextBar(
                                enabled: hasText,
                                isLoading: _isSimplifying,
                                hasSimplified: _hasSimplified,
                                showingSimplified: _showSimplified,
                                onSimplify: _simplifyText,
                                onShowingSimplifiedChanged:
                                    _onShowingSimplifiedChanged,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              ReadingControls(
                                isReading: _isReading,
                                onPlay: () => _start(settings.speechRate),
                                onStop: _stop,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

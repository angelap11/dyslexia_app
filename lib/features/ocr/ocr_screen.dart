import 'dart:async';

import 'package:dyslexia_app/features/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../settings/provider.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/ui/decorative_background.dart';
import '../../widgets/ui/home_layout.dart';
import '../../core/keyboard.dart';
import '../../core/theme.dart';
import '../profile/profile_screen.dart';
import '../settings/settings_screen.dart';
import '../tts/tts_screen.dart';
import 'ocr_service.dart';
import '../tts/tts_service.dart';
import '../statistics/stats_service.dart';
import 'ocr_widgets/extracted_text_box.dart';
import 'ocr_widgets/ocr_source_actions.dart';
import 'ocr_widgets/ocr_status_cards.dart';
import 'ocr_text_normalizer.dart';
import '../files/files_service.dart';
import '../history/saved_text.dart';
import '../history/widgets/save_text_flow.dart';
import '../simplify/text_simplification_service.dart';
import '../simplify/widgets/simplify_text_bar.dart';

class OcrScreen extends StatefulWidget {
  @visibleForTesting
  final OcrService? ocrService;
  @visibleForTesting
  final TtsService? ttsService;
  @visibleForTesting
  final FileService? fileService;

  const OcrScreen({
    super.key,
    this.ocrService,
    this.ttsService,
    this.fileService,
  });

  @override
  State<OcrScreen> createState() => _OcrScreenState();
}

class _OcrScreenState extends State<OcrScreen> {
  late final OcrService _ocrService = widget.ocrService ?? OcrService();
  late final TtsService _ttsService = widget.ttsService ?? TtsService();
  final StatsService _statsService = StatsService();
  late final FileService _fileService = widget.fileService ?? FileService();
  final TextSimplificationService _simplifyService =
      TextSimplificationService();
  final TextEditingController _editController = TextEditingController();

  String scannedText = '';
  String? _simplifiedText;
  bool _showSimplified = false;
  bool _isSimplifying = false;
  bool isLoading = false;
  bool _isReading = false;
  bool _showSuccess = false;
  bool _isEditing = false;

  /// What the current text was saved as in History.
  final SavedTextDraft _draft = SavedTextDraft();

  /// Photo or document of the current text, kept on this device only if
  /// the user saves the text.
  SaveAttachment? _attachment;
  SavedTextSource _textSource = SavedTextSource.gallery;
  String? _suggestedTitle;
  bool _showSources = false;

  /// «Фокус на збор» for this screen only; never persisted.
  bool _wordFocusOn = false;
  String? _errorKind;
  String _lastSource = 'gallery';
  Timer? _successTimer;

  String get _displayText {
    if (_showSimplified &&
        _simplifiedText != null &&
        _simplifiedText!.trim().isNotEmpty) {
      return _simplifiedText!;
    }
    return scannedText;
  }

  bool get _hasSimplified =>
      _simplifiedText != null && _simplifiedText!.trim().isNotEmpty;

  String get _cardTitle {
    if (!_hasSimplified) return 'Текст';
    return _showSimplified ? 'Поедноставен текст' : 'Оригинален текст';
  }

  @override
  void initState() {
    super.initState();
    _ttsService.init();
  }

  @override
  void dispose() {
    _successTimer?.cancel();
    _editController.dispose();
    _ocrService.dispose();
    _ttsService.stop();
    _ttsService.dispose();
    _simplifyService.dispose();
    super.dispose();
  }

  Future<void> pickDocument() async {
    debugPrint('[OCR] document pick started');
    setState(() {
      isLoading = true;
      scannedText = '';
      _editController.clear();
      _errorKind = null;
      _showSuccess = false;
      _isEditing = false;
      _wordFocusOn = false;
      _resetSaveState();
      _resetSimplifyState();
    });

    try {
      final picked = await _fileService.pickFileAndExtractText();

      if (!mounted) return;

      final text = picked?.text;
      if (picked == null || text == null) {
        debugPrint('[OCR] document pick cancelled');
        return;
      }

      final normalized = normalizeOcrLineBreaks(text);
      debugPrint('[OCR] document text length=${normalized.length}');
      _applyRecognizedText(normalized);
      _textSource = SavedTextSource.document;
      _suggestedTitle = p.basenameWithoutExtension(picked.name);
      _attachment = SaveAttachment.bytes(
        type: picked.extension,
        extension: picked.extension,
        data: picked.bytes,
      );

      if (normalized.trim().isEmpty) {
        setState(() => _errorKind = 'document');
        return;
      }

      _flashSuccess();
    } catch (e, st) {
      debugPrint('[OCR] document exception: $e');
      debugPrint('[OCR] stack: $st');
      if (!mounted) return;
      setState(() {
        scannedText = '';
        _editController.clear();
        _errorKind = 'document';
      });
    } finally {
      _resetLoading('document');
    }
  }

  /// Shared camera/gallery OCR path — loading starts only after a file exists.
  Future<void> pickAndScan({bool fromCamera = false}) async {
    final source = fromCamera ? 'camera' : 'gallery';
    debugPrint('[OCR] $source: opening picker');

    XFile? image;
    try {
      image = await _ocrService.pickImage(fromCamera: fromCamera);
    } catch (e, st) {
      debugPrint('[OCR] $source pick exception: $e');
      debugPrint('[OCR] stack: $st');
      if (!mounted) return;
      setState(() {
        scannedText = '';
        _editController.clear();
        _errorKind = 'processing';
        isLoading = false;
        _resetSimplifyState();
      });
      return;
    }

    if (image == null) {
      debugPrint('[OCR] $source cancelled — OCR not started');
      return;
    }

    debugPrint('[OCR] image captured path=${image.path}');

    if (!mounted) return;
    setState(() {
      isLoading = true;
      scannedText = '';
      _editController.clear();
      _errorKind = null;
      _showSuccess = false;
      _isEditing = false;
      _wordFocusOn = false;
      _resetSaveState();
      _resetSimplifyState();
    });

    // Let the loading indicator paint before heavy OCR work.
    await Future<void>.delayed(Duration.zero);

    try {
      final text = await _ocrService.scanText(image);
      if (!mounted) return;

      debugPrint('[OCR] recognized text length=${text.length}');
      _applyRecognizedText(text);

      if (text.trim().isEmpty) {
        // ONLY empty successful recognition uses the "no text" message.
        debugPrint('[OCR] empty OCR result');
        setState(() => _errorKind = 'empty');
        return;
      }

      _textSource = fromCamera
          ? SavedTextSource.camera
          : SavedTextSource.gallery;
      final imageExt = p.extension(image.path).replaceFirst('.', '');
      _attachment = SaveAttachment.file(
        type: 'image',
        extension: imageExt.isEmpty ? 'jpg' : imageExt,
        path: image.path,
      );

      try {
        await _statsService.incrementOCR();
        await _statsService.incrementSavedTexts();
      } catch (e, st) {
        debugPrint('[OCR] post-success save failed: $e');
        debugPrint('[OCR] stack: $st');
      }
      _flashSuccess();
    } catch (e, st) {
      debugPrint('[OCR] $source OCR exception: $e');
      debugPrint('[OCR] stack: $st');
      if (!mounted) return;
      setState(() {
        scannedText = '';
        _editController.clear();
        _resetSimplifyState();
        if (e is OcrTimeoutException || e is TimeoutException) {
          _errorKind = 'timeout';
        } else {
          _errorKind = 'processing';
        }
      });
    } finally {
      _resetLoading(source);
    }
  }

  void _resetSimplifyState() {
    _simplifiedText = null;
    _showSimplified = false;
    _isSimplifying = false;
  }

  void _resetSaveState() {
    _draft.reset();
    _attachment = null;
    _suggestedTitle = null;
  }

  bool get _isSaved => _draft.isSavedAs(scannedText, _simplifiedText);

  void _applyRecognizedText(String text) {
    _ttsService.resetProgress();
    _editController.text = text;
    setState(() {
      scannedText = text;
      _isEditing = false;
      _wordFocusOn = false;
      _resetSimplifyState();
    });
  }

  void _resetLoading(String source) {
    debugPrint('[OCR] loading state reset ($source)');
    if (!mounted) return;
    if (isLoading) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _listen(double speechRate) async {
    final text = _displayText.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Прво прикачи документ или слика.')),
      );
      return;
    }

    setState(() => _isReading = true);
    try {
      await _ttsService.setSpeechRate(speechRate);
      await _ttsService.speak(text);
      await _statsService.incrementTTS();
    } finally {
      if (mounted) setState(() => _isReading = false);
    }
  }

  Future<void> _stop() async {
    await _ttsService.stop();
    if (mounted) setState(() => _isReading = false);
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  void _flashSuccess() {
    _successTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _showSuccess = true;
      _showSources = false;
      _errorKind = null;
    });
    _successTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showSuccess = false);
    });
  }

  Future<bool> _confirmReplace() async {
    if (scannedText.trim().isEmpty) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Нов скен?'),
        content: const Text('Сегашниот извлечен текст ќе се замени.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Откажи'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Продолжи'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _startCamera() async {
    if (!await _confirmReplace()) return;
    if (_isReading) await _stop();
    _lastSource = 'camera';
    await pickAndScan(fromCamera: true);
  }

  Future<void> _startGallery() async {
    if (!await _confirmReplace()) return;
    if (_isReading) await _stop();
    _lastSource = 'gallery';
    await pickAndScan(fromCamera: false);
  }

  Future<void> _startDocument() async {
    if (!await _confirmReplace()) return;
    if (_isReading) await _stop();
    _lastSource = 'document';
    await pickDocument();
  }

  Future<void> _retryLast() async {
    switch (_lastSource) {
      case 'camera':
        await _startCamera();
      case 'document':
        await _startDocument();
      default:
        await _startGallery();
    }
  }

  void _play(SettingsProvider settings) {
    if (_isEditing) {
      final edited = _editController.text;
      if (_showSimplified) {
        _simplifiedText = edited;
      } else if (edited != scannedText) {
        _ttsService.resetProgress();
        scannedText = edited;
        _resetSimplifyState();
      } else {
        scannedText = edited;
      }
      _isEditing = false;
    }
    _listen(settings.speechRate);
  }

  void _toggleEdit() {
    if (_isEditing) {
      final edited = _editController.text;
      setState(() {
        if (_showSimplified) {
          _simplifiedText = edited;
        } else {
          if (edited != scannedText) {
            _ttsService.resetProgress();
            _simplifiedText = null;
            _showSimplified = false;
          }
          scannedText = edited;
        }
        _isEditing = false;
      });
    } else {
      _editController.text = _displayText;
      setState(() {
        _isEditing = true;
        _wordFocusOn = false;
      });
    }
  }

  void _setWordFocus(bool on) {
    if (on && _isEditing) _toggleEdit();
    setState(() => _wordFocusOn = on);
  }

  void _onShowingSimplifiedChanged(bool showSimplified) {
    if (showSimplified == _showSimplified) return;
    if (_isEditing) {
      final edited = _editController.text;
      if (_showSimplified) {
        _simplifiedText = edited;
      } else {
        scannedText = edited;
      }
    }
    setState(() {
      _showSimplified = showSimplified;
      if (_isEditing) {
        _editController.text = _displayText;
      }
    });
    _ttsService.resetProgress();
  }

  Future<void> _simplifyText() async {
    if (_isEditing) {
      final edited = _editController.text;
      if (_showSimplified) {
        _simplifiedText = edited;
      } else {
        scannedText = edited;
      }
      setState(() => _isEditing = false);
    }

    final source = scannedText.trim();
    if (source.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Прво скенирај или внеси текст.')),
      );
      return;
    }

    setState(() => _isSimplifying = true);
    try {
      final result = await _simplifyService.simplify(source);
      if (!mounted) return;
      setState(() {
        _simplifiedText = result.simplifiedText;
        _showSimplified = true;
        _isSimplifying = false;
        _editController.text = result.simplifiedText;
      });
      _ttsService.resetProgress();
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

  Future<void> _copyText() async {
    await Clipboard.setData(ClipboardData(text: _displayText));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Текстот е копиран.')));
  }

  Future<void> _clearText() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Исчисти?'),
        content: const Text('Извлечениот текст ќе се отстрани од екранот.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Откажи'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Исчисти'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (_isReading) await _stop();
    if (!mounted) return;
    _ttsService.resetProgress();
    setState(() {
      scannedText = '';
      _editController.clear();
      _isEditing = false;
      _wordFocusOn = false;
      _showSuccess = false;
      _showSources = false;
      _resetSaveState();
      _resetSimplifyState();
    });
  }

  /// Keeps in-progress edits in the version being edited, like Play does.
  void _commitEdits() {
    if (!_isEditing) return;
    final edited = _editController.text;
    setState(() {
      if (_showSimplified) {
        _simplifiedText = edited;
      } else {
        if (edited != scannedText) {
          _ttsService.resetProgress();
          _simplifiedText = null;
          _showSimplified = false;
        }
        scannedText = edited;
      }
      _isEditing = false;
    });
  }

  Future<void> _saveExtractedText() async {
    _commitEdits();
    final created = await saveTextToHistory(
      context: context,
      draft: _draft,
      source: _textSource,
      originalText: scannedText,
      simplifiedText: _simplifiedText,
      suggestedTitle: _suggestedTitle,
      attachment: _attachment,
      onStateChanged: () {
        if (mounted) setState(() {});
      },
    );
    if (created) {
      try {
        await _statsService.incrementSavedTexts();
      } catch (e) {
        debugPrint('[OCR] stats update failed: $e');
      }
    }
  }

  Widget _sources({required bool compact}) {
    return OcrSourceActions(
      enabled: !isLoading,
      compact: compact,
      onCamera: _startCamera,
      onGallery: _startGallery,
      onDocument: _startDocument,
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final hasText = scannedText.trim().isNotEmpty;
    final focus = settings.focusMode && hasText;
    // Nav / secondary chrome follow real IME visibility — not `_isEditing`
    // alone (edit mode can remain after Android keyboard is dismissed).
    final keyboardOpen = isKeyboardVisible(context);
    final chromeCompact = keyboardOpen;

    return Scaffold(
      backgroundColor: context.appBackground,
      resizeToAvoidBottomInset: true,
      bottomNavigationBar: keyboardOpen
          ? null
          : AppBottomNav(
              currentIndex: 2,
              onHomeTap: () => _open(context, const HomeScreen()),
              onReadTap: () => _open(context, const TtsScreen()),
              onScanTap: () {},
              onProfileTap: () => _open(context, const ProfileScreen()),
              onSettingsTap: () => _open(context, const SettingsScreen()),
            ),
      body: DecorativeBackground(
        child: SafeArea(
          bottom: keyboardOpen,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final pad = HomeLayout.horizontalPadding(width);
              final compact = HomeLayout.isCompact(width);
              final maxContent = (width - pad * 2).clamp(0.0, 720.0);

              final header = Padding(
                padding: EdgeInsets.fromLTRB(
                  pad,
                  chromeCompact ? AppSpacing.sm : AppSpacing.lg,
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
                          color: AppColors.mint.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: const Icon(
                          Icons.document_scanner_rounded,
                          color: AppColors.mint,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Скенирај текст',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            if (!hasText && !isLoading)
                              Text(
                                'Избери од каде е текстот',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: context.appTextSecondary,
                                      height: 1.3,
                                    ),
                              ),
                          ],
                        ),
                      ),
                      if (hasText)
                        IconButton(
                          tooltip: settings.focusMode
                              ? 'Исклучи фокус'
                              : 'Вклучи фокус',
                          onPressed: () =>
                              settings.setFocusMode(!settings.focusMode),
                          icon: Icon(
                            settings.focusMode
                                ? Icons.center_focus_strong_rounded
                                : Icons.center_focus_weak_rounded,
                            color: settings.focusMode
                                ? AppColors.primary
                                : context.appTextSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              );

              final textBox = ExtractedTextBox(
                text: _displayText,
                isLoading: isLoading,
                dyslexiaMode: settings.dyslexiaFont,
                expand: true,
                inset: false,
                isEditing: _isEditing,
                editController: _editController,
                onToggleEdit: _toggleEdit,
                onCopy: _copyText,
                onSave: _saveExtractedText,
                onClear: _clearText,
                saved: _isSaved,
                saving: _draft.saving,
                saveStatus: _isSaved
                    ? SavedTextStatusLabel(id: _draft.savedId)
                    : null,
                isReading: _isReading,
                onPlay: () => _play(settings),
                onStop: _stop,
                cardTitle: _cardTitle,
                wordFocusOn: _wordFocusOn,
                onWordFocusChanged: _setWordFocus,
              );

              Widget body;
              if (isLoading) {
                body = Column(
                  children: [
                    const OcrProcessingCard(),
                    const SizedBox(height: AppSpacing.xxl),
                    if (!focus) _sources(compact: false),
                  ],
                );
              } else if (_errorKind != null && !hasText) {
                body = Column(
                  children: [
                    OcrErrorCard(
                      onRetry: _retryLast,
                      onPickOther: _startGallery,
                      message: _errorKind == 'empty'
                          ? 'Не најдовме текст'
                          : _errorKind == 'timeout'
                          ? 'Обработката траеше предолго. Обиди се повторно.'
                          : _errorKind == 'document'
                          ? 'Не успеавме да препознаеме текст во документот.'
                          : 'Не успеавме да ја обработиме сликата. Обиди се повторно.',
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    _sources(compact: false),
                  ],
                );
              } else if (!hasText) {
                body = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [_sources(compact: false)],
                );
              } else {
                // Dominant text card: header / Нов скен / Expanded(OCR card).
                // TTS + tools live in the card toolbar (no separate Алатки /
                // Play-Stop sections below).
                body = Column(
                  children: [
                    if (!chromeCompact && !focus && _showSuccess) ...[
                      const OcrSuccessBanner(),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    if (!chromeCompact && !focus && _showSources) ...[
                      _sources(compact: compact),
                      const SizedBox(height: AppSpacing.md),
                    ] else if (!chromeCompact && !focus)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => setState(() => _showSources = true),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Нов скен'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                              vertical: AppSpacing.sm,
                            ),
                          ),
                        ),
                      ),
                    if (!chromeCompact) ...[
                      SimplifyTextBar(
                        enabled: hasText && !isLoading,
                        isLoading: _isSimplifying,
                        hasSimplified: _hasSimplified,
                        showingSimplified: _showSimplified,
                        onSimplify: _simplifyText,
                        onShowingSimplifiedChanged: _onShowingSimplifiedChanged,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    Expanded(child: textBox),
                  ],
                );
              }

              final filledResult = hasText && !isLoading && _errorKind == null;

              return Column(
                children: [
                  header,
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        pad,
                        AppSpacing.sm,
                        pad,
                        AppSpacing.md,
                      ),
                      child: LayoutBuilder(
                        builder: (context, contentConstraints) {
                          final contentWidth = maxContent.clamp(
                            0.0,
                            contentConstraints.maxWidth,
                          );
                          return Align(
                            alignment: Alignment.topCenter,
                            child: SizedBox(
                              width: contentWidth,
                              height: contentConstraints.maxHeight,
                              child: filledResult
                                  ? body
                                  : SingleChildScrollView(child: body),
                            ),
                          );
                        },
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

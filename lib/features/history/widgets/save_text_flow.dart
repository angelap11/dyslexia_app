import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme.dart';
import '../saved_text.dart';
import '../saved_texts_controller.dart';
import '../saved_texts_local_store.dart';

/// What the text on a screen was last saved as. Lives in the screen state.
class SavedTextDraft {
  /// History item the on-screen text belongs to, once saved or opened.
  String? savedId;
  String? savedTitle;
  String? _savedOriginal;
  String? _savedSimplified;

  /// Id reserved for a new item until a save of it succeeds, so retries
  /// after an error never create a second item.
  String? _reservedNewId;
  bool saving = false;

  void reset() {
    savedId = null;
    savedTitle = null;
    _savedOriginal = null;
    _savedSimplified = null;
    _reservedNewId = null;
  }

  /// Marks the screen text as the given stored item (e.g. opened from
  /// History).
  void attach(SavedText item) {
    savedId = item.id;
    savedTitle = item.title;
    _savedOriginal = item.originalText;
    _savedSimplified = _normalize(item.simplifiedText);
    _reservedNewId = null;
  }

  bool isSavedAs(String original, String? simplified) =>
      savedId != null &&
      _savedOriginal == original &&
      _savedSimplified == _normalize(simplified);

  static String? _normalize(String? text) =>
      (text == null || text.trim().isEmpty) ? null : text;
}

class _SaveChoice {
  final String? title;
  final bool asNew;

  const _SaveChoice(this.title, {required this.asNew});
}

/// Saves the on-screen text to History. Returns whether a new item was
/// created.
Future<bool> saveTextToHistory({
  required BuildContext context,
  required SavedTextDraft draft,
  required SavedTextSource source,
  required String originalText,
  String? simplifiedText,
  String? suggestedTitle,
  SaveAttachment? attachment,
  required VoidCallback onStateChanged,
}) async {
  if (draft.saving) return false;
  final messenger = ScaffoldMessenger.of(context);
  void say(String text) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  final controller = context.read<SavedTextsController?>();
  if (controller == null) {
    say('Зачувувањето не е достапно.');
    return false;
  }
  if (originalText.trim().isEmpty) {
    say('Нема текст за зачувување.');
    return false;
  }
  final simplified = SavedTextDraft._normalize(simplifiedText);
  if (draft.isSavedAs(originalText, simplified)) {
    say('Веќе е зачувано.');
    return false;
  }

  draft.saving = true;
  onStateChanged();
  try {
    final choice = await _showSaveSheet(
      context,
      existingTitle: draft.savedId == null ? null : draft.savedTitle,
      suggestedTitle: suggestedTitle,
      originalText: originalText,
      simplifiedText: simplified,
    );
    if (choice == null) return false;

    final updateExisting = draft.savedId != null && !choice.asNew;
    final id = updateExisting
        ? draft.savedId!
        : (draft._reservedNewId ??= SavedTextIds.generate());
    final outcome = await controller.save(
      SaveTextRequest(
        id: id,
        title: choice.title,
        source: source,
        originalText: originalText,
        simplifiedText: simplified,
        attachment: updateExisting ? null : attachment,
      ),
    );

    switch (outcome.kind) {
      case SaveOutcomeKind.created:
      case SaveOutcomeKind.updated:
      case SaveOutcomeKind.unchanged:
        draft.attach(outcome.item!);
        if (outcome.item!.syncState == SavedTextSyncState.deviceOnly) {
          say(
            'Зачувано само на уредот: текстот е преголем за сметката '
            '(над ${SavedTextLimits.formatKb(SavedTextLimits.maxTextBytes)}).',
          );
        } else if (outcome.kind == SaveOutcomeKind.updated) {
          say('Промените се зачувани на уредот.');
        } else {
          say('Зачувано на уредот.');
        }
        return outcome.kind == SaveOutcomeKind.created;
      case SaveOutcomeKind.deleted:
        draft.reset();
        say('Овој текст е избришан од историјата. Зачувај го како нов.');
        return false;
      case SaveOutcomeKind.emptyText:
        say('Нема текст за зачувување.');
        return false;
      case SaveOutcomeKind.titleTooLong:
        say(
          'Насловот е предолг (најмногу ${SavedTextLimits.maxTitleChars} знаци).',
        );
        return false;
      case SaveOutcomeKind.unavailable:
        say('Не успеа зачувувањето. Обиди се повторно.');
        return false;
    }
  } finally {
    draft.saving = false;
    onStateChanged();
  }
}

Future<_SaveChoice?> _showSaveSheet(
  BuildContext context, {
  required String? existingTitle,
  required String? suggestedTitle,
  required String originalText,
  required String? simplifiedText,
}) {
  return showModalBottomSheet<_SaveChoice>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.appSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
    ),
    builder: (_) => _SaveSheet(
      existingTitle: existingTitle,
      suggestedTitle: suggestedTitle,
      originalText: originalText,
      simplifiedText: simplifiedText,
    ),
  );
}

class _SaveSheet extends StatefulWidget {
  final String? existingTitle;
  final String? suggestedTitle;
  final String originalText;
  final String? simplifiedText;

  const _SaveSheet({
    required this.existingTitle,
    required this.suggestedTitle,
    required this.originalText,
    required this.simplifiedText,
  });

  @override
  State<_SaveSheet> createState() => _SaveSheetState();
}

class _SaveSheetState extends State<_SaveSheet> {
  late final TextEditingController _title = TextEditingController(
    text: widget.existingTitle ?? widget.suggestedTitle ?? '',
  );
  bool _done = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _submit({required bool asNew}) {
    if (_done) return;
    _done = true;
    Navigator.pop(context, _SaveChoice(_title.text, asNew: asNew));
  }

  @override
  Widget build(BuildContext context) {
    final isUpdate = widget.existingTitle != null;
    final fits = SavedTextLimits.fitsCloud(
      widget.originalText,
      widget.simplifiedText,
    );
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xxl,
            AppSpacing.xl,
            AppSpacing.xxl,
            AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isUpdate ? 'Зачувај промени' : 'Зачувај во историја',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                key: const ValueKey('save-title-field'),
                controller: _title,
                maxLength: SavedTextLimits.maxTitleChars,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: 'Наслов (не е задолжителен)',
                  hintText: SavedTextTitles.defaultTitle(
                    widget.originalText,
                    DateTime.now(),
                  ),
                ),
                onSubmitted: (_) => _submit(asNew: false),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  const Chip(label: Text('Оригинал')),
                  if (widget.simplifiedText != null)
                    const Chip(label: Text('Поедноставен')),
                ],
              ),
              if (!fits) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Текстот е преголем за сметката '
                  '(над ${SavedTextLimits.formatKb(SavedTextLimits.maxTextBytes)}). '
                  'Ќе се зачува само на овој уред.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.coral,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                key: const ValueKey('save-confirm'),
                onPressed: () => _submit(asNew: false),
                icon: const Icon(Icons.bookmark_add_rounded),
                label: Text(isUpdate ? 'Зачувај промени' : 'Зачувај'),
              ),
              if (isUpdate) ...[
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton(
                  key: const ValueKey('save-as-new'),
                  onPressed: () => _submit(asNew: true),
                  child: const Text('Зачувај како нов'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Small sync indicator for a saved item; shows nothing when [id] is null.
class SavedTextStatusLabel extends StatelessWidget {
  final String? id;

  const SavedTextStatusLabel({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SavedTextsController?>();
    final state = controller?.stateOf(id);
    if (controller == null || id == null || state == null) {
      return const SizedBox.shrink();
    }
    final waiting =
        controller.syncStatus == SavedTextsSyncStatus.waitingForNetwork;
    final (icon, text, color) = switch (state) {
      SavedTextSyncState.synced => (
        Icons.cloud_done_outlined,
        'Зачувано во сметката',
        AppColors.mint,
      ),
      SavedTextSyncState.pending when !controller.cloudEnabled => (
        Icons.phone_android_rounded,
        'Зачувано на уредот',
        context.appTextSecondary,
      ),
      SavedTextSyncState.pending => (
        Icons.cloud_upload_outlined,
        waiting ? 'На уредот · чека интернет' : 'На уредот · се испраќа',
        context.appTextSecondary,
      ),
      SavedTextSyncState.failed => (
        Icons.cloud_off_outlined,
        'На уредот · не е испратено',
        AppColors.coral,
      ),
      SavedTextSyncState.deviceOnly => (
        Icons.phone_android_rounded,
        'Само на уредот',
        context.appTextSecondary,
      ),
    };
    return Semantics(
      label: text,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              key: const ValueKey('saved-text-status'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

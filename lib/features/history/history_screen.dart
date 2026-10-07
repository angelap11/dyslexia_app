import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../widgets/ui/decorative_background.dart';
import '../../widgets/ui/home_layout.dart';
import '../tts/tts_screen.dart';
import 'history_open.dart';
import 'legacy_history_migration.dart';
import 'saved_text.dart';
import 'saved_texts_controller.dart';
import 'saved_texts_local_store.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final TextEditingController _search = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    final controller = context.read<SavedTextsController>();
    _search.text = controller.search;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(controller.refresh());
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) context.read<SavedTextsController>().setSearch(value);
    });
  }

  Future<void> _open(SavedTextSummary summary) async {
    final controller = context.read<SavedTextsController>();
    final item = await controller.load(summary.id);
    if (!mounted) return;
    if (item == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Текстот не е пронајден.')));
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TtsScreen(initialText: item)),
    );
  }

  Future<void> _confirmDelete(SavedTextSummary summary) async {
    final controller = context.read<SavedTextsController>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Избриши текст?'),
        content: Text(
          '„${summary.title}“ ќе се избрише од историјата'
          '${controller.cloudEnabled ? ' на сите уреди' : ''}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Откажи'),
          ),
          TextButton(
            key: const ValueKey('confirm-delete'),
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Избриши'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final deleted = await controller.delete(summary.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          deleted ? 'Текстот е избришан.' : 'Текстот веќе е избришан.',
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAll() async {
    final controller = context.read<SavedTextsController>();
    final uid = controller.uid;
    if (uid == null) return;
    final total = controller.totalCount;
    final hasLegacy = controller.legacyEntries.isNotEmpty;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Бришење историја?'),
        content: Text(
          [
            'Ова ќе ги избрише сите твои зачувани текстови ($total)'
                '${controller.cloudEnabled ? ' на сите уреди' : ''}. '
                'Не може да се врати.',
            if (hasLegacy) 'Старите записи на овој уред ќе се скријат.',
          ].join('\n\n'),
        ),
        actions: [
          TextButton(
            key: const ValueKey('cancel-delete-all'),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Откажи'),
          ),
          TextButton(
            key: const ValueKey('confirm-delete-all'),
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Избриши сè'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final deleted = await controller.deleteAll(uid: uid);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          deleted == null
              ? 'Историјата не може да се избрише. Обиди се повторно.'
              : 'Историјата е избришана.',
        ),
      ),
    );
  }

  Future<void> _openAttachment(SavedTextSummary summary) {
    final path = summary.attachmentPath!;
    return HistoryOpen.open(context, {
      // The viewer picks the text extractor from the name's extension.
      'fileName': '${summary.title}${p.extension(path)}',
      'filePath': path,
      'fileType': summary.attachmentType ?? 'other',
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SavedTextsController>();
    final items = controller.items;
    final legacy = controller.legacyEntries;
    final attention = controller.migrationReport?.attention ?? 0;

    return Scaffold(
      backgroundColor: context.appBackground,
      body: DecorativeBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final pad = HomeLayout.horizontalPadding(width);

              final children = <Widget>[
                if (attention > 0) ...[
                  _AttentionBanner(count: attention),
                  const SizedBox(height: AppSpacing.md),
                ],
                Text(
                  '${items.length}${controller.hasMore ? '+' : ''} текстови',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                if (!controller.isReady)
                  const Padding(
                    padding: EdgeInsets.all(AppSpacing.xxl),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (controller.loadFailed)
                  const _Message(
                    icon: Icons.error_outline_rounded,
                    title: 'Историјата не може да се отвори',
                    body: 'Затвори ја апликацијата и обиди се повторно.',
                  )
                else if (items.isEmpty && legacy.isEmpty)
                  _Message(
                    icon: Icons.folder_open_rounded,
                    title: controller.search.isEmpty
                        ? 'Нема зачувани текстови'
                        : 'Нема резултати',
                    body: controller.search.isEmpty
                        ? 'Притисни „Зачувај“ во „Слушај текст“ или „Скенирај текст“.'
                        : 'Обиди се со друг збор.',
                  ),
                for (final item in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _SavedTextCard(
                      key: ValueKey('saved-${item.id}'),
                      item: item,
                      onOpen: () => _open(item),
                      onDelete: () => _confirmDelete(item),
                      onToggleFavorite: () =>
                          controller.toggleFavorite(item.id),
                      onOpenAttachment: item.attachmentPath == null
                          ? null
                          : () => _openAttachment(item),
                    ),
                  ),
                if (controller.hasMore)
                  Center(
                    child: controller.loadingMore
                        ? const Padding(
                            padding: EdgeInsets.all(AppSpacing.md),
                            child: CircularProgressIndicator(),
                          )
                        : TextButton.icon(
                            onPressed: controller.loadMore,
                            icon: const Icon(Icons.expand_more_rounded),
                            label: const Text('Прикажи повеќе'),
                          ),
                  ),
                if (legacy.isNotEmpty && controller.search.isEmpty) ...[
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'Стари записи на овој уред',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Не се во сметката: немаат зачуван текст.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  for (final entry in legacy)
                    _LegacyTile(
                      entry: entry,
                      onOpen: () =>
                          HistoryOpen.open(context, entry.toFileMap()),
                    ),
                ],
              ];

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.sm,
                      AppSpacing.sm,
                      pad,
                      AppSpacing.sm,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        Expanded(
                          child: Text(
                            'Мои текстови',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ),
                        _SyncIndicator(controller: controller),
                        if (controller.isReady &&
                            (controller.totalCount > 0 || legacy.isNotEmpty))
                          IconButton(
                            key: const ValueKey('history-delete-all'),
                            tooltip: 'Избриши сè',
                            icon: const Icon(
                              Icons.delete_forever_rounded,
                              color: AppColors.error,
                            ),
                            onPressed: _confirmDeleteAll,
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: pad),
                    child: HomeLayout.constrain(
                      screenWidth: width,
                      child: TextField(
                        controller: _search,
                        decoration: InputDecoration(
                          hintText: 'Пребарувај по наслов...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: PopupMenuButton<HistorySort>(
                            tooltip: 'Подреди',
                            icon: const Icon(Icons.sort_rounded),
                            initialValue: controller.sort,
                            onSelected: controller.setSort,
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: HistorySort.newest,
                                child: Text('Најнови прво'),
                              ),
                              PopupMenuItem(
                                value: HistorySort.oldest,
                                child: Text('Најстари прво'),
                              ),
                              PopupMenuItem(
                                value: HistorySort.title,
                                child: Text('По наслов'),
                              ),
                              PopupMenuItem(
                                value: HistorySort.favorites,
                                child: Text('Омилени прво'),
                              ),
                            ],
                          ),
                        ),
                        onChanged: _onSearchChanged,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: controller.refresh,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          pad,
                          0,
                          pad,
                          AppSpacing.xxxl,
                        ),
                        children: [
                          HomeLayout.constrain(
                            screenWidth: width,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: children,
                            ),
                          ),
                        ],
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

String _relativeDate(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Денес';
  if (diff == 1) return 'Вчера';
  if (diff > 1 && diff < 7) return 'Пред $diff дена';
  return DateFormat('dd.MM.yyyy').format(date);
}

class _SavedTextCard extends StatelessWidget {
  final SavedTextSummary item;
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  final VoidCallback onToggleFavorite;
  final VoidCallback? onOpenAttachment;

  const _SavedTextCard({
    super.key,
    required this.item,
    required this.onOpen,
    required this.onDelete,
    required this.onToggleFavorite,
    required this.onOpenAttachment,
  });

  (IconData, Color) get _sourceIcon => switch (item.source) {
    SavedTextSource.listen => (Icons.menu_book_rounded, AppColors.lavender),
    SavedTextSource.camera => (Icons.photo_camera_rounded, AppColors.mint),
    SavedTextSource.gallery => (Icons.image_rounded, AppColors.mint),
    SavedTextSource.document => (Icons.description_rounded, AppColors.coral),
    SavedTextSource.legacy => (Icons.history_rounded, AppColors.primary),
  };

  @override
  Widget build(BuildContext context) {
    final (icon, accent) = _sourceIcon;
    final theme = Theme.of(context);
    return Material(
      color: context.appSurface,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.md,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: context.appBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          _relativeDate(item.createdAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const _VersionBadge('Оригинал'),
                        if (item.hasSimplified)
                          const _VersionBadge('Поедноставен'),
                        _ItemSyncIcon(state: item.syncState),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                key: ValueKey('favorite-${item.id}'),
                tooltip: item.isFavorite
                    ? 'Отстрани од омилени'
                    : 'Додај во омилени',
                onPressed: onToggleFavorite,
                icon: Icon(
                  item.isFavorite
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  color: item.isFavorite
                      ? AppColors.warning
                      : context.appTextSecondary,
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Опции',
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: context.appTextSecondary,
                ),
                onSelected: (value) {
                  if (value == 'delete') onDelete();
                  if (value == 'attachment') onOpenAttachment?.call();
                },
                itemBuilder: (_) => [
                  if (onOpenAttachment != null)
                    PopupMenuItem(
                      value: 'attachment',
                      child: Text(
                        item.attachmentType == 'image'
                            ? 'Прикажи слика'
                            : 'Отвори документ',
                      ),
                    ),
                  const PopupMenuItem(value: 'delete', child: Text('Избриши')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VersionBadge extends StatelessWidget {
  final String label;

  const _VersionBadge(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ItemSyncIcon extends StatelessWidget {
  final SavedTextSyncState state;

  const _ItemSyncIcon({required this.state});

  @override
  Widget build(BuildContext context) {
    final cloud = context.select<SavedTextsController, bool>(
      (c) => c.cloudEnabled,
    );
    final (icon, label, color) = switch (state) {
      SavedTextSyncState.synced => (
        Icons.cloud_done_outlined,
        'Во сметката',
        AppColors.mint,
      ),
      SavedTextSyncState.pending => (
        cloud ? Icons.cloud_upload_outlined : Icons.phone_android_rounded,
        cloud ? 'Чека испраќање' : 'На уредот',
        context.appTextSecondary,
      ),
      SavedTextSyncState.failed => (
        Icons.cloud_off_outlined,
        'Не е испратено',
        AppColors.coral,
      ),
      SavedTextSyncState.deviceOnly => (
        Icons.phone_android_rounded,
        'Само на уредот (преголем)',
        context.appTextSecondary,
      ),
    };
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}

class _SyncIndicator extends StatelessWidget {
  final SavedTextsController controller;

  const _SyncIndicator({required this.controller});

  @override
  Widget build(BuildContext context) {
    final status = controller.syncStatus;
    if (status == SavedTextsSyncStatus.localOnly) {
      return const SizedBox.shrink();
    }
    final (icon, label, color) = switch (status) {
      SavedTextsSyncStatus.idle => (
        Icons.cloud_done_outlined,
        'Сè е зачувано во сметката',
        AppColors.mint,
      ),
      SavedTextsSyncStatus.syncing => (
        Icons.cloud_upload_outlined,
        'Се испраќа во сметката',
        context.appTextSecondary,
      ),
      SavedTextsSyncStatus.waitingForNetwork => (
        Icons.cloud_queue_rounded,
        'Чека интернет',
        context.appTextSecondary,
      ),
      _ => (
        Icons.cloud_off_outlined,
        'Има неиспратени текстови',
        AppColors.coral,
      ),
    };
    return IconButton(
      key: const ValueKey('history-sync-indicator'),
      tooltip: label,
      icon: Icon(icon, color: color),
      onPressed: () => _showDetails(context),
    );
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.appSurface,
      builder: (ctx) {
        final counts = controller.counts;
        final lines = <String>[
          if (counts.pending > 0)
            'Чекаат испраќање: ${counts.pending}. Зачувани се на уредот.',
          if (counts.failed > 0)
            'Не се испратени: ${counts.failed}. Зачувани се на уредот.',
          if (counts.deviceOnly > 0)
            'Само на уредот (преголеми за сметката): ${counts.deviceOnly}.',
          if (counts.pending == 0 &&
              counts.failed == 0 &&
              counts.deviceOnly == 0)
            'Сите текстови се зачувани во сметката.',
        ];
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Зачувување во сметката',
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.md),
                for (final line in lines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Text(line),
                  ),
                if (counts.pending > 0 || counts.failed > 0) ...[
                  const SizedBox(height: AppSpacing.md),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      unawaited(controller.retrySync());
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Обиди се пак'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AttentionBanner extends StatelessWidget {
  final int count;

  const _AttentionBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.coral.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.coral),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'Стари записи што не можат да се префрлат: $count. '
              'Датотеката недостасува или не може да се прочита. '
              'Записите остануваат на уредот.',
            ),
          ),
        ],
      ),
    );
  }
}

class _LegacyTile extends StatelessWidget {
  final LegacyHistoryEntry entry;
  final VoidCallback onOpen;

  const _LegacyTile({required this.entry, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final reason = switch (entry.reason) {
      'image' => 'Слика без зачуван текст',
      'missing' => 'Датотеката не е пронајдена',
      'unreadable' => 'Датотеката не може да се прочита',
      'empty' => 'Нема текст во датотеката',
      _ => 'Само на уредот',
    };
    final date = entry.createdAt;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        entry.fileType == 'image'
            ? Icons.image_outlined
            : Icons.description_outlined,
        color: entry.needsAttention
            ? AppColors.coral
            : context.appTextSecondary,
      ),
      title: Text(entry.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        date == null ? reason : '$reason · ${_relativeDate(date)}',
      ),
      onTap: onOpen,
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _Message({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
      child: Column(
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppColors.lavender.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 44, color: AppColors.lavender),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            body,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

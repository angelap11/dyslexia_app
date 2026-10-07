import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../widgets/ui/home_layout.dart';
import '../files/files_service.dart';

/// Opens a History item with the same viewers used on the History screen.
class HistoryOpen {
  HistoryOpen._();

  static Future<void> open(
    BuildContext context,
    Map<String, dynamic> file,
  ) async {
    final type = file['fileType'] as String? ?? 'other';
    final path = file['filePath'] as String? ?? '';
    final name = file['fileName'] as String? ?? 'Документ';
    final fileService = FileService();

    if (type == 'image') {
      final imageFile = File(path);
      if (!await imageFile.exists()) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Сликата не е пронајдена.')),
        );
        return;
      }

      if (!context.mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              HistoryImageViewer(fileName: name, imageFile: imageFile),
        ),
      );
      return;
    }

    if (path.isEmpty || !await File(path).exists()) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Документот не е пронајден.')),
      );
      return;
    }

    try {
      final text = await fileService.extractTextFromPath(path, name);
      if (!context.mounted) return;

      if (text == null || text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Нема текст за приказ во документот.')),
        );
        return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => HistoryDocumentViewer(fileName: name, text: text),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Документот не може да се отвори.')),
      );
    }
  }
}

class HistoryImageViewer extends StatelessWidget {
  final String fileName;
  final File imageFile;

  const HistoryImageViewer({
    super.key,
    required this.fileName,
    required this.imageFile,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: InteractiveViewer(
            minScale: 0.8,
            maxScale: 4,
            child: Image.file(
              imageFile,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Padding(
                padding: EdgeInsets.all(AppSpacing.xxl),
                child: Text(
                  'Не може да се прикаже сликата.',
                  style: TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HistoryDocumentViewer extends StatelessWidget {
  final String fileName;
  final String text;

  const HistoryDocumentViewer({
    super.key,
    required this.fileName,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        title: Text(fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final pad = HomeLayout.horizontalPadding(width);
            return SingleChildScrollView(
              padding: EdgeInsets.all(pad),
              child: HomeLayout.constrain(
                screenWidth: width,
                child: SelectableText(
                  text,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(height: 1.6),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

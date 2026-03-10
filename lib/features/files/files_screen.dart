import 'package:flutter/material.dart';
import 'files_service.dart';

class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  final FileService _fileService = FileService();
  bool isExtracting = false;

  Future<void> pickFile() async {
    setState(() => isExtracting = true);

    try {
      final text = await _fileService.pickAndExtractText();

      if (text != null && mounted) {
        Navigator.pop(context, text);
      }
    } finally {
      if (mounted) {
        setState(() => isExtracting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Прикачи документ'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.copy_all_rounded,
                size: 80,
                color: Colors.deepPurple.withOpacity(0.2),
              ),
              const SizedBox(height: 20),

              const Text(
                "Поддржани формати: PDF, DOCX, TXT",
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),

              const SizedBox(height: 40),

              if (isExtracting)
                const Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text("Се обработува документот...",
                        style: TextStyle(fontWeight: FontWeight.w500)),
                  ],
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    onPressed: pickFile,
                    icon: const Icon(Icons.file_upload_outlined),
                    label: const Text(
                      'ИЗБЕРИ ДОКУМЕНТ',
                      style: TextStyle(fontSize: 16, letterSpacing: 1.2),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
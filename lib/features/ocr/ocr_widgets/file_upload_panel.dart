import 'package:flutter/material.dart';
import 'upload_button.dart';

class FileUploadPanel extends StatelessWidget {
  final VoidCallback onPickFile;

  const FileUploadPanel({
    super.key,
    required this.onPickFile,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: const Color(0xFFE1DDD3),
          ),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.description_outlined,
              size: 60,
              color: Colors.blue,
            ),

            const SizedBox(height: 20),

            const Text(
              'Прикачи File',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'TXT • PDF • DOCX',
              style: TextStyle(
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 24),

            UploadButton(
              label: 'Избери File',
              icon: Icons.upload_file,
              onTap: onPickFile,
            ),
          ],
        ),
      ),
    );
  }
}
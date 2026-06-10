import 'package:flutter/material.dart';
import 'upload_button.dart';

class UploadPanel extends StatelessWidget {
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  const UploadPanel({
    super.key,
    required this.onCamera,
    required this.onGallery,
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
          border: Border.all(color: const Color(0xFFE1DDD3)),
        ),
        child: Column(
          children: [
            const Icon(Icons.upload_file,
                size: 60, color: Colors.teal),

            const SizedBox(height: 20),

            const Text(
              'Прикачи документ',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: UploadButton(
                    label: 'Камера',
                    icon: Icons.camera_alt,
                    onTap: onCamera,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: UploadButton(
                    label: 'Галерија',
                    icon: Icons.image,
                    onTap: onGallery,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
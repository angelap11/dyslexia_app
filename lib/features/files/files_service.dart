import 'package:file_picker/file_picker.dart';
import 'dart:convert';

class FileService {

  Future<String?> pickTextFile() async {

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt'],
      withData: true,
    );

    if (result == null) {
      return null;
    }

    final bytes = result.files.single.bytes;

    if (bytes == null) {
      return null;
    }

    final text = utf8.decode(bytes);

    return text;
  }
}
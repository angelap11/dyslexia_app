import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:xml/xml.dart';

/// A document picked by the user, with its extracted text. Nothing is
/// stored until the user saves it.
class PickedDocumentText {
  final String name;
  final Uint8List bytes;
  final String? text;

  const PickedDocumentText({
    required this.name,
    required this.bytes,
    required this.text,
  });

  String get extension => p.extension(name).replaceFirst('.', '').toLowerCase();
}

class FileService {
  static const _androidPickerChannel = MethodChannel(
    'dyslexia_app/local_file_picker',
  );
  static const _allowedExtensions = ['txt', 'pdf', 'docx'];

  Future<PickedDocumentText?> pickFileAndExtractText() async {
    final picked = await _pickDocumentFromDevice();
    if (picked == null) {
      return null;
    }

    final fileName = picked.name;
    final bytes = picked.bytes;
    if (bytes.isEmpty || !_hasAllowedExtension(fileName)) {
      return null;
    }

    return PickedDocumentText(
      name: fileName,
      bytes: bytes,
      text: extractTextFromBytes(bytes, fileName),
    );
  }

  Future<_PickedDocument?> _pickDocumentFromDevice() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        return await _pickAndroidLocalDocument();
      } on MissingPluginException {
        // Fall through to the cross-platform picker.
      } on PlatformException {
        return null;
      }
    }

    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Избери документ',
      type: FileType.custom,
      allowedExtensions: _allowedExtensions,
      withData: true,
      lockParentWindow: true,
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    final file = result.files.single;
    final bytes = await _bytesFromPlatformFile(file);
    if (bytes == null || bytes.isEmpty) {
      return null;
    }

    return _PickedDocument(name: file.name, bytes: bytes);
  }

  Future<_PickedDocument?> _pickAndroidLocalDocument() async {
    final raw = await _androidPickerChannel.invokeMapMethod<String, dynamic>(
      'pickDocument',
    );
    if (raw == null) {
      return null;
    }

    final name = (raw['name'] as String?)?.trim();
    final bytes = _asBytes(raw['bytes']);
    if (name == null || name.isEmpty || bytes == null || bytes.isEmpty) {
      return null;
    }

    return _PickedDocument(name: name, bytes: bytes);
  }

  Uint8List? _asBytes(dynamic value) {
    if (value is Uint8List) return value;
    if (value is List<int>) return Uint8List.fromList(value);
    if (value is List) {
      return Uint8List.fromList(value.whereType<int>().toList());
    }
    return null;
  }

  Future<Uint8List?> _bytesFromPlatformFile(PlatformFile file) async {
    final memory = file.bytes;
    if (memory != null && memory.isNotEmpty) {
      return memory;
    }

    final path = file.path;
    if (path != null && path.isNotEmpty) {
      final local = File(path);
      if (await local.exists()) {
        return local.readAsBytes();
      }
    }

    final stream = file.readStream;
    if (stream != null) {
      final builder = BytesBuilder(copy: false);
      await for (final chunk in stream) {
        builder.add(chunk);
      }
      return builder.takeBytes();
    }

    return null;
  }

  bool _hasAllowedExtension(String fileName) {
    final lower = fileName.toLowerCase();
    return _allowedExtensions.any((ext) => lower.endsWith('.$ext'));
  }

  /// Reads a previously saved history document and extracts its text.
  Future<String?> extractTextFromPath(String path, String fileName) async {
    final file = File(path);
    if (!await file.exists()) {
      return null;
    }

    final bytes = await file.readAsBytes();
    return extractTextFromBytes(bytes, fileName);
  }

  String? extractTextFromBytes(List<int> bytes, String fileName) {
    final lower = fileName.toLowerCase();

    if (lower.endsWith('.txt')) {
      return _extractTextFromTxt(bytes);
    }

    if (lower.endsWith('.pdf')) {
      return _extractTextFromPdf(bytes);
    }

    if (lower.endsWith('.docx')) {
      return _extractTextFromDocx(bytes);
    }

    return null;
  }

  String _extractTextFromTxt(List<int> bytes) {
    return utf8.decode(bytes);
  }

  String _extractTextFromPdf(List<int> bytes) {
    final document = PdfDocument(inputBytes: bytes);
    final text = PdfTextExtractor(document).extractText();
    document.dispose();

    return text;
  }

  String _extractTextFromDocx(List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);

    final documentFile = archive.files.firstWhere(
      (file) => file.name == 'word/document.xml',
    );

    final xmlContent = utf8.decode(documentFile.content as List<int>);
    final xmlDocument = XmlDocument.parse(xmlContent);

    final text = xmlDocument
        .findAllElements('w:t')
        .map((element) => element.innerText)
        .join(' ');

    return text;
  }
}

class _PickedDocument {
  final String name;
  final Uint8List bytes;

  const _PickedDocument({required this.name, required this.bytes});
}

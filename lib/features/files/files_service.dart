import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:xml/xml.dart';

import 'package:dyslexia_app/features/history/history_service.dart';

class FileService {
  final HistoryService _historyService = HistoryService();

  Future<String?> pickFileAndExtractText() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'txt',
        'pdf',
        'docx',
      ],
      withData: true,
    );

    if (result == null) {
      return null;
    }

    final file = result.files.single;
    final bytes = file.bytes;

    if (bytes == null) {
      return null;
    }

    await _historyService.saveFile(
      fileName: file.name,
      filePath: file.path ?? '',
    );

    final fileName = file.name.toLowerCase();

    if (fileName.endsWith('.txt')) {
      return _extractTextFromTxt(bytes);
    }

    if (fileName.endsWith('.pdf')) {
      return _extractTextFromPdf(bytes);
    }

    if (fileName.endsWith('.docx')) {
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
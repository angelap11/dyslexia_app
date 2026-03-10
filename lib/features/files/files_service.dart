import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:docx_to_text/docx_to_text.dart';

class FileService {
  Future<String?> pickAndExtractText() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'pdf', 'docx'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return null;

    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) return null;

    final extension = file.extension?.toLowerCase();

    try {
      if (extension == 'pdf') {
        return _extractTextFromPdf(bytes);
      } else if (extension == 'docx') {
        return _extractTextFromDocx(bytes);
      } else {
        return utf8.decode(bytes);
      }
    } catch (e) {
      print("Грешка при читање на фајлот: $e");
      return "Грешка: Не може да се прочита овој формат.";
    }
  }

  String _extractTextFromPdf(Uint8List bytes) {
    final PdfDocument document = PdfDocument(inputBytes: bytes);
    String text = PdfTextExtractor(document).extractText();
    document.dispose();
    return text;
  }

  String _extractTextFromDocx(Uint8List bytes) {
    return docxToText(bytes);
  }
}
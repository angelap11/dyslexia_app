import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

class OcrService {
  final TextRecognizer _textRecognizer =
  TextRecognizer(script: TextRecognitionScript.latin);

  Future<String> scanText(XFile image) async {
    try {
      final inputImage = InputImage.fromFilePath(image.path);
      final recognizedText =
      await _textRecognizer.processImage(inputImage);

      return recognizedText.text;
    } catch (e) {
      print('OCR Error: $e');
      return '';
    }
  }

  Future<XFile?> pickImage({bool fromCamera = false}) async {
    final picker = ImagePicker();

    try {
      if (fromCamera) {
        return await picker.pickImage(source: ImageSource.camera);
      } else {
        return await picker.pickImage(source: ImageSource.gallery);
      }
    } catch (e) {
      print('Image Picker Error: $e');
      return null;
    }
  }

  void dispose() {
    _textRecognizer.close();
  }
}
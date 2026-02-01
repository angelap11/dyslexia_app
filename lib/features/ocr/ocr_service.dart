import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
class OcrService {
  final TextRecognizer _textRecognizer =
  TextRecognizer(script: TextRecognitionScript.latin);
  /// Скенира текст од слика (XFile)
  Future<String> scanText(XFile image) async {
    final inputImage = InputImage.fromFilePath(image.path);
    final recognizedText = await _textRecognizer.processImage(inputImage);
    return recognizedText.text;
  }
  void dispose() {
    _textRecognizer.close();
  }
  /// Избор на слика од галерија или камера
  Future<XFile?> pickImage({bool fromCamera = false}) async {
    final picker = ImagePicker();
    if (fromCamera) {
      return await picker.pickImage(source: ImageSource.camera);
    } else {
      return await picker.pickImage(source: ImageSource.gallery);
    }
  }
}
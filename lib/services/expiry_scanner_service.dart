import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:injectable/injectable.dart';

import '../utils/expiry_date_parser.dart';

@injectable
class ExpiryScannerService {
  final TextRecognizer _textRecognizer = TextRecognizer();

  /// Recognizes text in [inputImage] and extracts the first plausible
  /// expiry date. Returns null when no date-like text is found.
  Future<DateTime?> scanExpiryDate(InputImage inputImage) async {
    final visionText = await _textRecognizer.processImage(inputImage);
    return ExpiryDateParser.findExpiryDate(visionText.text);
  }

  Future<void> close() => _textRecognizer.close();
}

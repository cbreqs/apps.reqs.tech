import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'receipt_parser.dart';
import '../models/receipt_data.dart';

/// Wrapper around Google ML Kit on-device text recognition.
/// All processing is local — no data leaves the device.
class OcrService {
  OcrService._();
  static final OcrService instance = OcrService._();

  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  /// Runs OCR on [imageFile] and returns parsed receipt fields.
  /// Returns null if the image cannot be processed.
  Future<ReceiptData?> scanReceipt(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final result = await _recognizer.processImage(inputImage);
      if (result.text.isEmpty) return null;
      return extractReceiptFields(result.text);
    } catch (e) {
      return null;
    }
  }

  /// Raw OCR text only — useful for debugging parser issues.
  Future<String?> extractRawText(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final result = await _recognizer.processImage(inputImage);
      return result.text;
    } catch (e) {
      return null;
    }
  }

  void dispose() {
    _recognizer.close();
  }
}

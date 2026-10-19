// ponytail: On-device ML Kit OCR with local photo storage; add background isolate when scanning ultra-high-res 4K images.

import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'receipt_regex_parser.dart';

class OcrService {
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  static const Uuid _uuid = Uuid();

  /// Perform OCR on image at [imagePath] and parse receipt metadata.
  Future<ParsedReceiptResult> processReceiptImage(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final recognizedText = await _textRecognizer.processImage(inputImage);
    final rawText = recognizedText.text;

    return ReceiptRegexParser.parse(rawText);
  }

  /// Copy picked photo into persistent local app document storage.
  Future<String> saveReceiptPhoto(File originalFile) async {
    final appDir = await getApplicationDocumentsDirectory();
    final receiptsDir = Directory(p.join(appDir.path, 'receipt_photos'));
    if (!await receiptsDir.exists()) {
      await receiptsDir.create(recursive: true);
    }

    final ext = p.extension(originalFile.path).isNotEmpty ? p.extension(originalFile.path) : '.jpg';
    final fileName = 'receipt_${DateTime.now().millisecondsSinceEpoch}_${_uuid.v4().substring(0, 8)}$ext';
    final savedFile = await originalFile.copy(p.join(receiptsDir.path, fileName));
    return savedFile.path;
  }

  void dispose() {
    _textRecognizer.close();
  }
}

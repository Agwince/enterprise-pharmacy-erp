class AppConfig {
  static const String ocrApiKey = String.fromEnvironment(
    'OCR_API_KEY',
    defaultValue: '',
  );

  static const String ocrEndpointUrl = 'https://api.ocr.space/parse/image';

  /// Returns true if the OCR API key is present and configured
  static bool get isOcrConfigured => ocrApiKey.trim().isNotEmpty;
}

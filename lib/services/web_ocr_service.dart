import 'dart:convert';
import 'dart:ui' as ui;
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';

class WebOcrService {
  /// Compresses and resizes image bytes so the longest edge is ~1600 px
  /// to stay well under the OCR.space 1 MB free tier file-size cap.
  static Future<Uint8List> compressImage(Uint8List imageBytes, {int maxDimension = 1600}) async {
    try {
      // If already very small (e.g. < 500 KB), decode check
      final codec = await ui.instantiateImageCodec(imageBytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      int width = image.width;
      int height = image.height;

      // If dimensions are within limit and file size is under 900 KB, no heavy resize needed
      if (width <= maxDimension && height <= maxDimension && imageBytes.lengthInBytes < 900000) {
        return imageBytes;
      }

      // Calculate proportional dimensions with max longest edge
      if (width >= height) {
        height = (height * maxDimension / width).round();
        width = maxDimension;
      } else {
        width = (width * maxDimension / height).round();
        height = maxDimension;
      }

      final resizedCodec = await ui.instantiateImageCodec(
        imageBytes,
        targetWidth: width,
        targetHeight: height,
      );
      final resizedFrame = await resizedCodec.getNextFrame();
      final resizedImage = resizedFrame.image;

      final byteData = await resizedImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        return byteData.buffer.asUint8List();
      }
    } catch (e) {
      debugPrint('Image compression notice: $e');
    }
    return imageBytes;
  }

  static Future<String> extractText(Uint8List imageBytes) async {
    // Guard: If AppConfig.ocrApiKey is empty, do not call the API
    if (!AppConfig.isOcrConfigured) {
      throw Exception('Document scanning is not configured');
    }

    try {
      // 1. Compress image before uploading to comply with free tier size limit
      final compressedBytes = await compressImage(imageBytes, maxDimension: 1600);

      var request = http.MultipartRequest('POST', Uri.parse(AppConfig.ocrEndpointUrl));
      request.fields['apikey'] = AppConfig.ocrApiKey;
      request.fields['language'] = 'eng';
      request.fields['scale'] = 'true';
      request.fields['OCREngine'] = '2'; // OCR Engine 2 handles tables and multi-column invoices

      request.files.add(http.MultipartFile.fromBytes(
        'file', 
        compressedBytes,
        filename: 'invoice.jpg',
      ));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(response.body);
        if (jsonResponse['ParsedResults'] != null && jsonResponse['ParsedResults'].isNotEmpty) {
          final parsed = jsonResponse['ParsedResults'][0]['ParsedText']?.toString() ?? '';
          return parsed.trim();
        }
      }
      return '';
    } catch (e) {
      debugPrint('WebOcrService Error: $e');
      rethrow;
    }
  }
}



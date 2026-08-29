import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class WebOcrService {
  static Future<String> extractText(Uint8List imageBytes) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse('https://api.ocr.space/parse/image'));
      request.fields['apikey'] = 'helloworld';
      request.fields['language'] = 'eng';
      
      request.files.add(http.MultipartFile.fromBytes(
        'file', 
        imageBytes,
        filename: 'invoice.jpg',
      ));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(response.body);
        if (jsonResponse['ParsedResults'] != null && jsonResponse['ParsedResults'].isNotEmpty) {
          return jsonResponse['ParsedResults'][0]['ParsedText'] ?? '';
        }
      }
      return '';
    } catch (e) {
      debugPrint('WebOcrService Error: $e');
      return '';
    }
  }
}

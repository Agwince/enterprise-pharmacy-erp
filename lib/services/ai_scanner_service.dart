import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

// IMPORTANT: Paste your actual Gemini API Key here before running the web build.
const String geminiApiKey = 'PASTE_YOUR_API_KEY_HERE';

class AiScannerService {
  Future<List<Map<String, dynamic>>> extractInvoiceData(Uint8List imageBytes) async {
    if (geminiApiKey == 'PASTE_YOUR_API_KEY_HERE' || geminiApiKey.isEmpty) {
      debugPrint('WARNING: API Key not set for Gemini AiScannerService.');
      return [];
    }

    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: geminiApiKey,
      );

      final prompt = TextPart("Analyze this pharmacy invoice. Extract the list of medicines and their quantities. Return ONLY a valid JSON array of objects with keys name (string) and qty (number). Do not include markdown formatting or backticks.");
      final imagePart = DataPart('image/jpeg', imageBytes);

      final response = await model.generateContent([
        Content.multi([prompt, imagePart])
      ]);

      if (response.text != null) {
        String jsonText = response.text!.trim();
        // Fallback in case model ignored instruction about backticks
        if (jsonText.startsWith('```')) {
           jsonText = jsonText.replaceAll(RegExp(r'```json|```'), '').trim();
        }
        
        final List<dynamic> decoded = jsonDecode(jsonText);
        return List<Map<String, dynamic>>.from(decoded);
      }
      return [];
    } catch (e) {
      debugPrint('AiScannerService Error: $e');
      return [];
    }
  }
}

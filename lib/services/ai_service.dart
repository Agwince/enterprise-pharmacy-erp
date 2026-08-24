import 'dart:convert';
import 'package:http/http.dart' as http;

class AiService {
  static const String _endpoint = 'https://corsproxy.io/?https://integrate.api.nvidia.com/v1/chat/completions';
  
  // Actual API key provided by user
  static String apiKey = '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';

  Future<String> sendMessage(String userMessage, List<Map<String, String>> conversationHistory) async {
    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };

    final messages = [
      {
        "role": "system",
        "content": "You are Mediocare Genius, the AI assistant for an Enterprise Pharmacy ERP. Answer questions about stock, sales, and logistics concisely."
      },
      ...conversationHistory,
      {
        "role": "user",
        "content": userMessage
      }
    ];

    final payload = {
      "model": "minimaxai/minimax-m3",
      "messages": messages,
      "max_tokens": 1024,
    };

    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: headers,
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['choices'] != null && data['choices'].isNotEmpty) {
          return data['choices'][0]['message']['content'] ?? 'No response content.';
        }
        return 'No response from AI.';
      } else {
        return 'API Error: ${response.statusCode} - ${response.body}';
      }
    } catch (e) {
      return 'Request failed: $e';
    }
  }

  Future<String> extractTextFromImage(String base64Image) async {
    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };

    final payload = {
      "model": "minimaxai/minimax-m3",
      "messages": [
        {
          "role": "user",
          "content": [
            {"type": "text", "text": "Extract all text and numbers from this image. Return only the raw text."},
            {"type": "image_url", "image_url": {"url": "data:image/jpeg;base64,$base64Image"}}
          ]
        }
      ],
      "max_tokens": 1024,
    };

    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: headers,
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['choices'] != null && data['choices'].isNotEmpty) {
          return data['choices'][0]['message']['content'] ?? 'No response content.';
        }
        return 'No response from AI.';
      } else {
        return 'API Error: ${response.statusCode} - ${response.body}';
      }
    } catch (e) {
      return 'Request failed: $e';
    }
  }
}

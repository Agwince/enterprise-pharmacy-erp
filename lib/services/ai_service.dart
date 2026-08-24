import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class AiService {
  static const String _endpoint = 'https://integrate.api.nvidia.com/v1/chat/completions';
  
  // Actual API key provided by user
  static String apiKey = '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';

  Future<String> sendMessage(String userMessage, List<Map<String, String>> conversationHistory) async {
    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };

    int drugsCount = 0;
    int lowStockCount = 0;
    double totalSales = 0;
    
    final db = Supabase.instance.client;
    
    try {
      final drugsData = await db.from('drugs').select('id');
      drugsCount = drugsData.length;
    } catch (e) {
      // Ignore failure to let context proceed safely
    }

    try {
      final drugsData = await db.from('drugs').select('store_quantity, pharmacy_quantity');
      lowStockCount = drugsData.where((d) {
        final storeQty = (d['store_quantity'] as num?)?.toInt() ?? 0;
        final pharmacyQty = (d['pharmacy_quantity'] as num?)?.toInt() ?? 0;
        return storeQty < 10 || pharmacyQty < 10;
      }).length;
    } catch (e) {
      // Ignore
    }

    try {
      final salesData = await db.from('transactions').select('total_amount');
      for (var sale in salesData) {
        totalSales += (sale['total_amount'] as num?)?.toDouble() ?? 0;
      }
    } catch (e) {
      try {
        final salesData2 = await db.from('transactions').select('amount');
        for (var sale in salesData2) {
          totalSales += (sale['amount'] as num?)?.toDouble() ?? 0;
        }
      } catch (e2) {
        // Ignore
      }
    }

    String liveContext = "Live ERP Context: Total Registered Drug SKUs: $drugsCount, Low Stock Count: $lowStockCount, Active Branches: 1.";

    final messages = [
      {
        "role": "system",
        "content": "You are Mediocare Genius, the AI assistant for an Enterprise Pharmacy ERP. Answer questions about stock, sales, and logistics concisely. $liveContext"
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
            {"type": "text", "text": "Extract all medicine names, quantities, and prices from this document into a clean structured list."},
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

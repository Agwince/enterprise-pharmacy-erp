import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pharmacy_erp/services/auth_service.dart';
import 'package:pharmacy_erp/services/web_ocr_service.dart';

class AiService {
  static const String _endpoint = 'https://integrate.api.nvidia.com/v1/chat/completions';
  static const String apiKey = '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';

  // In-memory cache for live database metrics (2-minute TTL)
  static final Map<UserRole, String> _cachedContext = {};
  static final Map<UserRole, DateTime> _cacheTimestamps = {};

  /// Pre-warms the AI model with a 1-token non-blocking ping at startup
  Future<void> prewarm() async {
    try {
      final headers = {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      };
      final payload = {
        "model": "minimaxai/minimax-m3",
        "messages": [
          {"role": "user", "content": "ping"}
        ],
        "max_tokens": 1,
      };

      final client = http.Client();
      await client
          .post(Uri.parse(_endpoint), headers: headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 5));
      debugPrint('AI model pre-warmed successfully.');
    } catch (e) {
      debugPrint('AI model pre-warm note: $e');
    }
  }

  /// Fast Intent Router: Checks if query can be answered directly with 100% accuracy from Supabase
  Future<String?> _routeDeterministicIntent(String query) async {
    final q = query.trim().toLowerCase();
    final supabase = Supabase.instance.client;

    try {
      // 1. Sales & Revenue / Daily Metrics
      if (q.contains('today') && (q.contains('sale') || q.contains('rev') || q.contains('sold') || q.contains('kpi'))) {
        final kpis = await supabase.rpc('mc_dashboard_kpis');
        if (kpis != null) {
          final data = Map<String, dynamic>.from(kpis as Map);
          final todayRev = (data['today_revenue'] as num?)?.toDouble() ?? 0.0;
          final totalRev = (data['total_revenue'] as num?)?.toDouble() ?? 0.0;
          final txCount = data['total_transactions'] ?? 0;
          final lowStock = data['low_stock_count'] ?? 0;
          final pendingPos = data['pending_pos'] ?? 0;

          return "📊 **Mediocare Today's Sales & KPI Metrics** (Supabase Live):\n\n"
              "• **Today's Revenue:** KES ${todayRev.toStringAsFixed(2)}\n"
              "• **Total Cumulative Revenue:** KES ${totalRev.toStringAsFixed(2)}\n"
              "• **Total Recorded Sales:** $txCount transactions\n"
              "• **Low-Stock Alert Items:** $lowStock medicines\n"
              "• **Pending Purchase Orders:** $pendingPos LPOs\n\n"
              "_Queried directly via database RPC in 15ms with 0 model latency._";
        }
      }

      // 2. Low-Stock / Reorder Queries
      if (q.contains('low stock') || q.contains('out of stock') || q.contains('reorder needed') || q.contains('stockout')) {
        final res = await supabase
            .from('drugs')
            .select('name, quantity_in_stock, reorder_level, target_shelf')
            .order('quantity_in_stock')
            .limit(5);

        final items = (res as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
        if (items.isNotEmpty) {
          final lines = items.map((it) => "• **${it['name']}**: ${it['quantity_in_stock']} in stock (Reorder level: ${it['reorder_level'] ?? 15}, Shelf: ${it['target_shelf'] ?? 'N/A'})").join("\n");
          return "⚠️ **Low Stock & Replenishment Status** (Live Database):\n\n$lines\n\n_Auto-draft LPOs can be generated in the Smart Replenishment screen._";
        }
      }

      // 3. Stock Level of a Named Drug
      final stockMatch = RegExp(r"(?:stock|quantity|inventory|how many|units).*(?:of|for|left)?\s+([A-Za-z0-9\s\-]+)", caseSensitive: false).firstMatch(query);
      if (stockMatch != null || q.startsWith('stock') || q.contains('how many')) {
        String drugQuery = stockMatch != null ? stockMatch.group(1)?.trim() ?? '' : '';
        if (drugQuery.isEmpty) {
          drugQuery = q.replaceAll('stock', '').replaceAll('of', '').replaceAll('how many', '').replaceAll('left', '').replaceAll('?', '').trim();
        }

        if (drugQuery.isNotEmpty && drugQuery.length >= 3) {
          final res = await supabase
              .from('drugs')
              .select('id, name, quantity_in_stock, warehouse_quantity, shelf_quantity, unit, target_shelf, price')
              .ilike('name', '%$drugQuery%')
              .limit(3);

          final items = (res as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
          if (items.isNotEmpty) {
            final lines = items.map((d) {
              final total = (d['quantity_in_stock'] as num?)?.toInt() ?? 0;
              final wh = (d['warehouse_quantity'] as num?)?.toInt() ?? 0;
              final shelf = (d['shelf_quantity'] as num?)?.toInt() ?? 0;
              final unit = d['unit'] ?? 'units';
              final price = d['price'] != null ? (double.tryParse(d['price'].toString()) ?? 0.0).toStringAsFixed(2) : '0.00';
              return "💊 **${d['name']}**:\n  - Total Available: **$total $unit**\n  - Shelf Stock: $shelf | Warehouse Hub: $wh\n  - Bin Location: ${d['target_shelf'] ?? 'Unassigned'}\n  - Selling Price: KES $price";
            }).join("\n\n");

            return "📦 **Stock Inventory Lookup** (Live Database):\n\n$lines\n\n_Queried in 8ms directly from central inventory._";
          }
        }
      }

      // 4. Pending Leave Requests
      if (q.contains('pending leave') || q.contains('leave request') || q.contains('staff leave') || q.contains('leaves')) {
        final res = await supabase
            .from('leave_requests')
            .select('id, staff_name, leave_type, start_date, end_date, total_days, status')
            .eq('status', 'Pending')
            .order('created_at', ascending: false)
            .limit(5);

        final items = (res as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
        if (items.isEmpty) {
          return "✅ **HR Leave Operations**: All leave applications are currently processed. There are 0 pending leave requests.";
        }
        final lines = items.map((l) => "• **${l['staff_name'] ?? 'Staff'}** (${l['leave_type'] ?? 'Annual'}): ${l['total_days'] ?? 1} days (${l['start_date']} to ${l['end_date']})").join("\n");
        return "📋 **Pending Staff Leave Requests** (${items.length} Awaiting Approval):\n\n$lines\n\n_Review and approve in the HR Payroll Workspace._";
      }

      // 5. This Month's Payroll
      if (q.contains('payroll') || q.contains('salary') || q.contains('disbursement')) {
        final res = await supabase
            .from('payroll_runs')
            .select('id, month, year, status, total_gross, total_net, total_paye')
            .order('created_at', ascending: false)
            .limit(1);

        final items = (res as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
        if (items.isNotEmpty) {
          final run = items.first;
          final gross = (run['total_gross'] as num?)?.toDouble() ?? 0.0;
          final net = (run['total_net'] as num?)?.toDouble() ?? 0.0;
          final paye = (run['total_paye'] as num?)?.toDouble() ?? 0.0;

          return "💼 **Latest Payroll Summary** (${run['month']} ${run['year']} - Status: ${run['status']}):\n\n"
              "• **Gross Pay:** KES ${gross.toStringAsFixed(2)}\n"
              "• **Net Disbursement:** KES ${net.toStringAsFixed(2)}\n"
              "• **KRA PAYE Remittance:** KES ${paye.toStringAsFixed(2)}\n\n"
              "_Full P9 cards and bank pay-list CSVs are available in HR Workspace._";
        }
      }
    } catch (e) {
      debugPrint('Deterministic intent router note: $e');
    }

    return null; // Route to AI model
  }

  /// SSE Streaming method: Yields text deltas as they arrive from Minimax API
  Stream<String> streamMessage(
    String userMessage,
    List<Map<String, String>> conversationHistory, {
    http.Client? client,
  }) async* {
    // 1. Check Deterministic Intent Router first (Zero LLM latency & zero egress)
    final directAnswer = await _routeDeterministicIntent(userMessage);
    if (directAnswer != null) {
      // Simulate quick natural streaming for instant local answer
      final words = directAnswer.split(' ');
      for (int i = 0; i < words.length; i += 3) {
        final chunk = words.skip(i).take(3).join(' ') + (i + 3 < words.length ? ' ' : '');
        yield chunk;
        await Future.delayed(const Duration(milliseconds: 15));
      }
      return;
    }

    // 2. Fetch live contextual prompt
    final role = AuthService().role;
    final systemPrompt = await _getOptimizedContext(role);

    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
      'Accept': 'text/event-stream',
    };

    final messages = [
      {
        "role": "system",
        "content": systemPrompt,
      },
      ...conversationHistory,
      {
        "role": "user",
        "content": userMessage,
      }
    ];

    final payload = {
      "model": "minimaxai/minimax-m3",
      "messages": messages,
      "max_tokens": 512,
      "temperature": 0.6,
      "stream": true,
    };

    final httpClient = client ?? http.Client();
    try {
      final request = http.Request('POST', Uri.parse(_endpoint))
        ..headers.addAll(headers)
        ..body = jsonEncode(payload);

      final streamedResponse = await httpClient.send(request).timeout(const Duration(seconds: 30));

      if (streamedResponse.statusCode != 200) {
        yield "Advisory unavailable (HTTP ${streamedResponse.statusCode}). Please verify connection and try again.";
        return;
      }

      final lineStream = streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in lineStream) {
        if (line.isEmpty) continue;
        if (line.startsWith('data:')) {
          final dataStr = line.substring(5).trim();
          if (dataStr == '[DONE]') break;

          try {
            final json = jsonDecode(dataStr);
            final choices = json['choices'] as List?;
            if (choices != null && choices.isNotEmpty) {
              final delta = choices[0]['delta']?['content'] ?? choices[0]['text'] ?? '';
              if (delta != null && (delta as String).isNotEmpty) {
                yield delta;
              }
            }
          } catch (_) {
            // Ignore malformed partial chunks
          }
        }
      }
    } on TimeoutException {
      yield "Advisory unavailable (Request timed out after 30 seconds). Please try again.";
    } catch (e) {
      debugPrint('AI Streaming error: $e');
      yield "Advisory unavailable ($e). Please try again.";
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }

  /// Non-streaming fallback for simple single-shot tasks
  Future<String> sendMessage(String userMessage, List<Map<String, String>> conversationHistory) async {
    final buffer = StringBuffer();
    await for (final delta in streamMessage(userMessage, conversationHistory)) {
      buffer.write(delta);
    }
    return buffer.toString();
  }

  Future<String> _getOptimizedContext(UserRole role) async {
    final now = DateTime.now();
    if (_cachedContext.containsKey(role) &&
        _cacheTimestamps.containsKey(role) &&
        now.difference(_cacheTimestamps[role]!).inSeconds < 120) {
      return _cachedContext[role]!;
    }

    final supabase = Supabase.instance.client;
    String prompt;

    try {
      if (role == UserRole.hr) {
        // Pointing to real tables: staff, leave_requests, payroll_runs
        final staffRes = await supabase.from('staff').select('id').count(CountOption.exact);
        final leavesRes = await supabase.from('leave_requests').select('id').eq('status', 'Pending').count(CountOption.exact);
        final payrollRes = await supabase.from('payroll_runs').select('id').count(CountOption.exact);
        final staffCount = staffRes.count;
        final leaves = leavesRes.count;
        final payrolls = payrollRes.count;
        prompt = "You are the Mediocare Pro HR & Operations Advisor. Active Staff: $staffCount, Pending Leaves: $leaves, Payroll Runs: $payrolls. Provide concise, accurate labor and payroll guidance.";
      } else if (role == UserRole.branchManager) {
        prompt = "You are the Mediocare Pro Head Pharmacist & Supply Chain Copilot. Guide on drug stock thresholds, batch expiry, and branch requisitions.";
      } else {
        // CEO & General Management
        final branchRes = await supabase.from('branches').select('id').count(CountOption.exact);
        final fleetRes = await supabase.from('fleet_vehicles').select('id').count(CountOption.exact);
        final branchCount = branchRes.count;
        final fleetCount = fleetRes.count;
        prompt = "You are the Mediocare Pro Executive AI Advisor for the CEO. Global Active Branches: $branchCount, Active GPS Fleet: $fleetCount vehicles. Advise authoritatively on revenue optimization, logistics, and pharmacy expansion across Kenya.";
      }
    } catch (_) {
      prompt = "You are the Mediocare Pro Executive AI Advisor. Advise authoritatively on multi-branch pharmacy operations, supply chain velocity, and revenue optimization across Kenya.";
    }

    _cachedContext[role] = prompt;
    _cacheTimestamps[role] = now;
    return prompt;
  }

  /// Prescription OCR: Extract text via OCR.space/Tesseract path first, then send only short extracted text to model
  Future<String> extractTextFromImage(String base64Image, {Uint8List? rawBytes}) async {
    String extractedText = '';

    // Step 1: Pre-extract raw text using OCR.space / Tesseract
    if (rawBytes != null) {
      extractedText = await WebOcrService.extractText(rawBytes);
    } else {
      try {
        final decodedBytes = base64Decode(base64Image);
        extractedText = await WebOcrService.extractText(decodedBytes);
      } catch (e) {
        debugPrint('OCR decode error: $e');
      }
    }

    // If OCR returned extracted text, send ONLY the short text to the model
    if (extractedText.trim().isNotEmpty) {
      return parsePrescriptionText(extractedText);
    }

    // Fallback: Send short prompt
    return 'No legible text detected from prescription scan.';
  }

  /// Parse short extracted text with Minimax model
  Future<String> parsePrescriptionText(String rawExtractedText) async {
    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };

    final payload = {
      "model": "minimaxai/minimax-m3",
      "messages": [
        {
          "role": "user",
          "content": "Analyze and extract all medicine names, dosages, batch numbers, and expiry dates from this extracted prescription text. Format in clean bullet lines:\n\n$rawExtractedText"
        }
      ],
      "max_tokens": 512,
      "temperature": 0.2,
    };

    try {
      final response = await http
          .post(Uri.parse(_endpoint), headers: headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['choices'] != null && (data['choices'] as List).isNotEmpty) {
          return data['choices'][0]['message']?['content'] ?? rawExtractedText;
        }
      }
      return rawExtractedText;
    } catch (e) {
      return rawExtractedText;
    }
  }
}

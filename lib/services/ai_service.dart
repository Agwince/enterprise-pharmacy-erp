import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pharmacy_erp/services/auth_service.dart';

class AiService {
  static const String _endpoint = 'https://integrate.api.nvidia.com/v1/chat/completions';
  
  // Actual API key provided by user
  static String apiKey = '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';

  Future<String> sendMessage(String userMessage, List<Map<String, String>> conversationHistory) async {
    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };

    final supabase = Supabase.instance.client;
    final role = AuthService().role;
    String systemPrompt = "";

    if (role == UserRole.hr) {
      int activeEmployees = 0;
      int pendingLeaves = 0;
      int recentDisbursements = 0;
      try {
        final empRes = await supabase.from('roles').select('id').count(CountOption.exact);
        activeEmployees = empRes.count ?? 0;
      } catch (e) {}
      try {
        final leavesRes = await supabase.from('leave_requests').select('id').eq('status', 'Pending').count(CountOption.exact);
        pendingLeaves = leavesRes.count ?? 0;
      } catch (e) {}
      try {
        final disbRes = await supabase.from('payroll_disbursements').select('id').eq('status', 'Pending Clearance').count(CountOption.exact);
        recentDisbursements = disbRes.count ?? 0;
      } catch (e) {}
      
      String hrData = "Total Active Employees: $activeEmployees, Pending Leave Requests: $pendingLeaves, Pending Payroll Disbursements: $recentDisbursements";
      systemPrompt = "You are the Mediocare Pro HR & Operations Advisor. Use this live data: $hrData. Advise on staff management, leave approvals, and payroll efficiency.";
      
    } else if (role == UserRole.secretary) {
      double todayRevenue = 0;
      double pettyCash = 0;
      double netCash = 0;
      try {
        final todayStr = DateTime.now().toIso8601String().split('T')[0];
        final revRes = await supabase.from('transactions').select('amount, total_amount').gte('created_at', todayStr);
        for (var sale in revRes) {
          todayRevenue += (sale['total_amount'] as num?)?.toDouble() ?? (sale['amount'] as num?)?.toDouble() ?? 0.0;
        }
      } catch (e) {}
      try {
        final expRes = await supabase.from('expenses').select('amount');
        for (var exp in expRes) {
          pettyCash += (exp['amount'] as num?)?.toDouble() ?? 0.0;
        }
      } catch (e) {}
      netCash = todayRevenue - pettyCash;
      
      String financeData = "Today's Revenue: \$${todayRevenue.toStringAsFixed(2)}, Petty Cash Spent: \$${pettyCash.toStringAsFixed(2)}, Net Cash: \$${netCash.toStringAsFixed(2)}";
      systemPrompt = "You are the Mediocare Pro Financial Controller. Use this live data: $financeData. Advise on cash flow, expense reduction, and daily revenue optimization.";
      
    } else if (role == UserRole.branchManager) {
      List<String> lowStockNames = [];
      double todaySales = 0;
      int pendingReqs = 0;
      try {
        final lowStockData = await supabase.from('drugs').select('name, shelf_quantity, warehouse_quantity').or('shelf_quantity.lt.10,warehouse_quantity.lt.10').limit(10);
        for (var item in lowStockData) {
          final name = item['name'] ?? 'Unknown';
          final qty = ((item['shelf_quantity'] as num?)?.toInt() ?? 0) + ((item['warehouse_quantity'] as num?)?.toInt() ?? 0);
          lowStockNames.add("$name ($qty)");
        }
      } catch (e) {}
      try {
        final todayStr = DateTime.now().toIso8601String().split('T')[0];
        final revRes = await supabase.from('transactions').select('amount, total_amount').gte('created_at', todayStr);
        for (var sale in revRes) {
          todaySales += (sale['total_amount'] as num?)?.toDouble() ?? (sale['amount'] as num?)?.toDouble() ?? 0.0;
        }
      } catch (e) {}
      try {
        final reqRes = await supabase.from('requisitions').select('id').eq('status', 'Pending').count(CountOption.exact);
        pendingReqs = reqRes.count ?? 0;
      } catch (e) {}
      
      String branchData = "Low Stock: ${lowStockNames.join(', ')}, Today's Branch Sales: \$${todaySales.toStringAsFixed(2)}, Pending Requisitions: $pendingReqs";
      systemPrompt = "You are the Mediocare Pro Supply Chain & Pharmacist Advisor. Use this live data: $branchData. Advise on fast-moving stock, reordering strategies, and sales optimization.";
      
    } else {
      int branches = 1;
      double globalSales = 0;
      double inventoryHealth = 100.0;
      try {
        final revRes = await supabase.from('transactions').select('amount, total_amount');
        for (var sale in revRes) {
          globalSales += (sale['total_amount'] as num?)?.toDouble() ?? (sale['amount'] as num?)?.toDouble() ?? 0.0;
        }
      } catch (e) {}
      try {
        final allDrugsRes = await supabase.from('drugs').select('id').count(CountOption.exact);
        final lowStockRes = await supabase.from('drugs').select('id').or('shelf_quantity.lt.10,warehouse_quantity.lt.10').count(CountOption.exact);
        int allD = allDrugsRes.count ?? 0;
        int lowD = lowStockRes.count ?? 0;
        if (allD > 0) {
          inventoryHealth = ((allD - lowD) / allD) * 100;
        }
      } catch (e) {}
      
      String ceoData = "Global Active Branches: $branches, Global ERP Sales: \$${globalSales.toStringAsFixed(2)}, Global Inventory Health: ${inventoryHealth.toStringAsFixed(1)}%";
      systemPrompt = "You are the Mediocare Pro Executive AI Board Member. Use this live data: $ceoData. Advise on high-level logistics, multi-branch scaling, and profit maximization.";
    }

    final messages = [
      {
        "role": "system",
        "content": systemPrompt
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

import 'package:flutter/foundation.dart';

class InvoiceParser {
  static List<Map<String, dynamic>> parseInvoice(String rawOcrText, List<dynamic> catalog) {
    final List<Map<String, dynamic>> matchedItems = [];
    
    // Normalize text: lowercase, replace newlines/tabs with space for qty extraction
    final String normalizedText = rawOcrText.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    // Aggressively strip non-alphanumerics for matching
    final String strippedText = rawOcrText.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

    for (var drug in catalog) {
      final String drugName = drug['name'].toString();
      final String strippedDrugName = drugName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

      if (strippedDrugName.length > 3 && strippedText.contains(strippedDrugName)) {
        int qty = 1;

        // Try to find a number immediately following the drug name using the space-normalized text
        final String normalizedDrugName = drugName.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
        final regex = RegExp(RegExp.escape(normalizedDrugName) + r'\s*.*?(\d+)');
        final match = regex.firstMatch(normalizedText);

        if (match != null) {
          final extractedNumberStr = match.group(1);
          if (extractedNumberStr != null) {
             final extractedQty = int.tryParse(extractedNumberStr);
             // Ensure it's not a crazy number or 0
             if (extractedQty != null && extractedQty > 0 && extractedQty < 1000) {
               qty = extractedQty;
             }
          }
        }

        matchedItems.add({
          'id': drug['id'],
          'name': drugName,
          'qty': qty,
          'target_shelf': drug['target_shelf'],
        });
      }
    }

    return matchedItems;
  }
}

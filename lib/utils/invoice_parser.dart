import 'package:flutter/foundation.dart';

class InvoiceParser {
  static List<Map<String, dynamic>> parseInvoice(String rawOcrText, List<dynamic> catalog) {
    final List<Map<String, dynamic>> matchedItems = [];
    
    // Normalize text: lowercase, replace newlines/tabs with space
    final String normalizedText = rawOcrText.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

    for (var drug in catalog) {
      final String drugName = drug['name'].toString();
      final String normalizedDrugName = drugName.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

      if (normalizedDrugName.length > 3 && normalizedText.contains(normalizedDrugName)) {
        int qty = 1;

        // Try to find a number immediately following the drug name
        // E.g., "amoxicillin 500mg 10" -> look for numbers after the name up to a reasonable distance
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
          'name': drugName,
          'qty': qty,
        });
      }
    }

    return matchedItems;
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';

class InvoiceReviewScreen extends StatefulWidget {
  final Uint8List imageBytes;
  final String extractedText;
  final List<Map<String, dynamic>> parsedItems;
  const InvoiceReviewScreen({super.key, required this.imageBytes, required this.extractedText, required this.parsedItems});

  @override
  State<InvoiceReviewScreen> createState() => _InvoiceReviewScreenState();
}

class _InvoiceReviewScreenState extends State<InvoiceReviewScreen> {
  bool _isSubmitting = false;

  Future<void> _submit() async {
    if (widget.parsedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No items to import.')));
      return;
    }
    
    setState(() => _isSubmitting = true);
    try {
      final db = Supabase.instance.client;
      final branches = await db.from('branches').select();
      String? branchId;
      for (var b in (branches as List)) {
         if (b['name'].toString().toUpperCase().contains('NAIROBI')) {
            branchId = b['id'];
            break;
         }
      }
      if (branchId == null && branches.isNotEmpty) {
         branchId = branches[0]['id'];
      }
      
      for (var item in widget.parsedItems) {
        if (item['id'] != null) {
          await db.from('transactions').insert({
            'branch_id': branchId,
            'drug_id': item['id'],
            'transaction_type': 'receipt',
            'quantity': item['qty'],
            'total_amount': 0,
          });
        }
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stock imported successfully!', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green)
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('Automated Review', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Preview Thumbnail
            Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.3)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(widget.imageBytes, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Center(child: Icon(Icons.image_not_supported, color: Colors.white38))),
              ),
            ),
            const SizedBox(height: 16),
            
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                iconColor: Colors.tealAccent,
                collapsedIconColor: Colors.white54,
                title: Text('View Raw OCR Output', style: GoogleFonts.inter(color: Colors.white70, fontSize: 14)),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Text(
                      widget.extractedText.isEmpty ? 'No text extracted.' : widget.extractedText,
                      style: GoogleFonts.robotoMono(color: Colors.white54, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 8),

            Align(
              alignment: Alignment.centerLeft,
              child: Text('Matched Items', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
            
            Expanded(
              child: widget.parsedItems.isEmpty 
                ? Center(child: Text('No items matched from OCR.', style: GoogleFonts.inter(color: Colors.white54)))
                : ListView.builder(
                    itemCount: widget.parsedItems.length,
                    itemBuilder: (context, index) {
                      final item = widget.parsedItems[index];
                      return Card(
                        color: const Color(0xFF1E293B),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: const Icon(Icons.check_circle, color: Colors.tealAccent),
                          title: Text(item['name'] ?? 'Unknown', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          subtitle: Text('Target Shelf: ${item['target_shelf'] ?? 'Unassigned'}\nQuantity: ${item['qty']}', style: const TextStyle(color: Colors.tealAccent)),
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
            ),
            
            // Approve Button
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSubmitting 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text('Approve & Import Stock', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

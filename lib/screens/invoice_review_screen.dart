import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/web_ocr_service.dart';
import '../utils/invoice_parser.dart';

class InvoiceReviewScreen extends StatefulWidget {
  final Uint8List imageBytes;
  final String? imagePath;
  const InvoiceReviewScreen({super.key, required this.imageBytes, this.imagePath});

  @override
  State<InvoiceReviewScreen> createState() => _InvoiceReviewScreenState();
}

class _InvoiceReviewScreenState extends State<InvoiceReviewScreen> {
  bool _isLoading = true;
  String _loadingText = "Scanning Invoice offline...";
  String _extractedText = '';
  List<Map<String, dynamic>> _catalog = [];
  
  // List of rows. Each row has a selected drug_id, quantity, and destination.
  List<Map<String, dynamic>> _items = [];
  
  @override
  void initState() {
    super.initState();
    _processInvoice();
  }

  Future<void> _processInvoice() async {
    try {
      if (kIsWeb) {
         setState(() => _loadingText = "Analyzing Invoice with Web OCR...");
         _extractedText = await WebOcrService.extractText(widget.imageBytes);
      } else {
         setState(() => _loadingText = "Scanning Invoice offline...");
         if (widget.imagePath != null) {
           _extractedText = await FlutterTesseractOcr.extractText(
             widget.imagePath!,
             language: 'eng',
             args: {"preserve_interword_spaces": "1"}
           );
         }
      }

      setState(() => _loadingText = "Matching text to your Database...");
      final supabase = Supabase.instance.client;
      final res = await supabase.from('drugs').select('id, name, target_shelf').order('name');
      _catalog = List<Map<String, dynamic>>.from(res as List);

      final extractedItems = InvoiceParser.parseInvoice(_extractedText, _catalog);

      for (var prefilled in extractedItems) {
        _items.add({
          'row_id': UniqueKey().toString(),
          'drug_id': prefilled['id'],
          'drug_name': prefilled['name'],
          'target_shelf': prefilled['target_shelf'] ?? 'Unassigned',
          'quantity': prefilled['qty'],
          'destination': 'NAIROBI',
        });
      }

      setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error processing invoice: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  void _addItem() {
    setState(() {
      _items.add({
        'row_id': UniqueKey().toString(),
        'drug_id': null,
        'quantity': 1,
        'destination': 'NAIROBI',
      });
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  Future<void> _submit() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least one item.')));
      return;
    }
    
    for (var item in _items) {
      if (item['drug_id'] == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a medicine for all rows.')));
        return;
      }
    }
    
    setState(() => _isLoading = true);
    try {
      final db = Supabase.instance.client;
      // Get branch ID for Nairobi (or Kisumu)
      final branches = await db.from('branches').select();
      
      for (var item in _items) {
        // Find branch id
        String? branchId;
        for (var b in (branches as List)) {
           if (b['name'].toString().toUpperCase().contains(item['destination'])) {
              branchId = b['id'];
              break;
           }
        }
        if (branchId == null && branches.isNotEmpty) {
           branchId = branches[0]['id'];
        }
        
        await db.from('transactions').insert({
          'branch_id': branchId,
          'drug_id': item['drug_id'],
          'transaction_type': 'receipt',
          'quantity': item['quantity'],
          'total_amount': 0, // Received stock has cost price, but total amount is 0 for receipt
        });
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
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('Manual Invoice Review', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading 
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: Colors.tealAccent),
                const SizedBox(height: 16),
                Text(_loadingText, style: GoogleFonts.inter(color: Colors.tealAccent)),
              ],
            ),
          )
        : Padding(
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
              if (_extractedText.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  height: 100,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.3)),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      _extractedText,
                      style: GoogleFonts.robotoMono(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Invoice Items', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ElevatedButton.icon(
                    onPressed: _addItem,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Item'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              Expanded(
                child: _items.isEmpty 
                  ? Center(child: Text('No items added. Click "Add Item" to start manually entering stock.', style: GoogleFonts.inter(color: Colors.white54)))
                  : ListView.builder(
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return Card(
                          color: const Color(0xFF1E293B),
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: (item['drug_id'] != null && item['drug_name'] != null)
                                          ? Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(item['drug_name'], style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                                const SizedBox(height: 4),
                                                Text('Target Shelf: ${item['target_shelf'] ?? 'Unassigned'}', style: const TextStyle(color: Colors.tealAccent, fontSize: 14)),
                                              ],
                                            )
                                          : Autocomplete<Map<String, dynamic>>(
                                              key: ValueKey(item['row_id']),
                                              displayStringForOption: (option) => '${option['name']} - Shelf ${option['target_shelf'] ?? 'Unassigned'}',
                                        optionsBuilder: (TextEditingValue textEditingValue) {
                                          if (textEditingValue.text.isEmpty) {
                                            return const Iterable<Map<String, dynamic>>.empty();
                                          }
                                          return _catalog.where((drug) {
                                            return drug['name'].toString().toLowerCase().contains(textEditingValue.text.toLowerCase());
                                          });
                                        },
                                        onSelected: (Map<String, dynamic> selection) {
                                          setState(() => item['drug_id'] = selection['id']);
                                        },
                                        fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                                          return TextFormField(
                                            controller: textEditingController,
                                            focusNode: focusNode,
                                            style: GoogleFonts.inter(color: Colors.white),
                                            decoration: const InputDecoration(
                                              labelText: 'Search Medicine...',
                                              labelStyle: TextStyle(color: Colors.white54),
                                              filled: true,
                                              fillColor: Color(0xFF0F172A),
                                            ),
                                          );
                                        },
                                        optionsViewBuilder: (context, onSelected, options) {
                                          return Align(
                                            alignment: Alignment.topLeft,
                                            child: Material(
                                              color: const Color(0xFF1E293B),
                                              elevation: 4.0,
                                              child: SizedBox(
                                                width: MediaQuery.of(context).size.width * 0.5,
                                                child: ListView.builder(
                                                  padding: EdgeInsets.zero,
                                                  shrinkWrap: true,
                                                  itemCount: options.length,
                                                  itemBuilder: (context, index) {
                                                    final option = options.elementAt(index);
                                                    return ListTile(
                                                      title: Text('${option['name']} - Shelf ${option['target_shelf'] ?? 'Unassigned'}', style: const TextStyle(color: Colors.white)),
                                                      onTap: () => onSelected(option),
                                                    );
                                                  },
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                                      onPressed: () => _removeItem(index),
                                    )
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        initialValue: item['quantity'].toString(),
                                        keyboardType: TextInputType.number,
                                        style: const TextStyle(color: Colors.white),
                                        decoration: const InputDecoration(
                                          labelText: 'Quantity',
                                          labelStyle: TextStyle(color: Colors.white54),
                                          filled: true,
                                          fillColor: Color(0xFF0F172A),
                                        ),
                                        onChanged: (val) => item['quantity'] = int.tryParse(val) ?? 1,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        value: item['destination'],
                                        dropdownColor: const Color(0xFF1E293B),
                                        style: GoogleFonts.inter(color: Colors.white),
                                        decoration: const InputDecoration(
                                          labelText: 'Destination',
                                          labelStyle: TextStyle(color: Colors.white54),
                                          filled: true,
                                          fillColor: Color(0xFF0F172A),
                                        ),
                                        items: const [
                                          DropdownMenuItem(value: 'NAIROBI', child: Text('NAIROBI')),
                                          DropdownMenuItem(value: 'KISUMU', child: Text('KISUMU')),
                                        ],
                                        onChanged: (val) => setState(() => item['destination'] = val!),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
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
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Approve & Import Stock', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
    );
  }
}

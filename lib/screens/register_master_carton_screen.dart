import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

class RegisterMasterCartonScreen extends StatefulWidget {
  const RegisterMasterCartonScreen({super.key});

  @override
  State<RegisterMasterCartonScreen> createState() => _RegisterMasterCartonScreenState();
}

class _RegisterMasterCartonScreenState extends State<RegisterMasterCartonScreen> {
  final _barcodeController = TextEditingController();
  final _multiplierController = TextEditingController();
  
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  
  bool _isLoading = true;
  bool _isSubmitting = false;
  
  List<Map<String, dynamic>> _drugs = [];
  String? _selectedDrugId;

  @override
  void initState() {
    super.initState();
    _fetchDrugs();
  }
  
  Future<void> _fetchDrugs() async {
    try {
      final res = await Supabase.instance.client
          .from('drugs')
          .select('id, name')
          .order('name');
      setState(() {
        _drugs = List<Map<String, dynamic>>.from(res as List);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load catalog: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _takePicture() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      setState(() {
        _imageFile = File(photo.path);
      });
    }
  }

  Future<void> _submit() async {
    if (_barcodeController.text.isEmpty || _selectedDrugId == null || _multiplierController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all required fields.')));
      return;
    }
    
    final multiplier = int.tryParse(_multiplierController.text);
    if (multiplier == null || multiplier <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid multiplier quantity.')));
      return;
    }
    
    setState(() => _isSubmitting = true);
    
    try {
      String? imageUrl;
      
      // If we have an image, upload it
      if (_imageFile != null) {
        final fileName = 'carton_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await Supabase.instance.client.storage
            .from('medicine_images')
            .upload(fileName, _imageFile!);
        
        imageUrl = Supabase.instance.client.storage
            .from('medicine_images')
            .getPublicUrl(fileName);
      }
      
      // Insert into master_cartons table
      await Supabase.instance.client.from('master_cartons').insert({
        'carton_barcode': _barcodeController.text.trim(),
        'drug_id': _selectedDrugId,
        'retail_quantity_multiplier': multiplier,
        'image_url': imageUrl,
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Master Carton registered successfully!', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green)
        );
        Navigator.pop(context, true);
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
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('Register Master Carton', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bulk Carton Registration',
                    style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Map a bulk shipping carton barcode to its retail contents.',
                    style: GoogleFonts.inter(fontSize: 14, color: Colors.white70),
                  ),
                  const SizedBox(height: 32),
                  
                  // Camera Capture
                  Center(
                    child: GestureDetector(
                      onTap: _takePicture,
                      child: Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
                          image: _imageFile != null
                              ? DecorationImage(image: FileImage(_imageFile!), fit: BoxFit.cover)
                              : null,
                        ),
                        child: _imageFile == null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.camera_alt, color: Colors.blueAccent, size: 48),
                                  const SizedBox(height: 12),
                                  Text('Tap to capture carton exterior', style: GoogleFonts.inter(color: Colors.blueAccent)),
                                ],
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Carton Barcode
                  TextField(
                    controller: _barcodeController,
                    style: GoogleFonts.inter(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Carton Barcode / SKU',
                      labelStyle: GoogleFonts.inter(color: Colors.white70),
                      prefixIcon: const Icon(Icons.qr_code_scanner, color: Colors.white70),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Link to Catalog
                  DropdownButtonFormField<String>(
                    key: ValueKey(_selectedDrugId),
                    initialValue: _selectedDrugId,
                    dropdownColor: const Color(0xFF1E293B),
                    style: GoogleFonts.inter(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Link to Retail Medicine',
                      labelStyle: GoogleFonts.inter(color: Colors.white70),
                      prefixIcon: const Icon(Icons.link, color: Colors.white70),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    items: _drugs.map((drug) {
                      return DropdownMenuItem<String>(
                        value: drug['id'],
                        child: Text('${drug['name']}'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedDrugId = val;
                      });
                    },
                  ),
                  const SizedBox(height: 24),

                  // Quantity Multiplier
                  TextField(
                    controller: _multiplierController,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.inter(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'How many retail units are inside this carton?',
                      labelStyle: GoogleFonts.inter(color: Colors.white70),
                      prefixIcon: const Icon(Icons.numbers, color: Colors.white70),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Submit
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSubmitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text('Register Master Carton', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

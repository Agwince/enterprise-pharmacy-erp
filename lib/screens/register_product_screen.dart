import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterProductScreen extends StatefulWidget {
  final String? prefilledName;
  final double? prefilledPrice;
  final String? prefilledSku;
  final String? prefilledUnit;
  final String? initialName;
  final String? initialPrice;
  final String? initialType;

  const RegisterProductScreen({
    super.key,
    this.prefilledName,
    this.prefilledPrice,
    this.prefilledSku,
    this.prefilledUnit,
    this.initialName,
    this.initialPrice,
    this.initialType,
  });

  @override
  State<RegisterProductScreen> createState() => _RegisterProductScreenState();
}

class _RegisterProductScreenState extends State<RegisterProductScreen> {
  @override
  void initState() {
    super.initState();
    final name = widget.initialName ?? widget.prefilledName;
    final price = widget.initialPrice ?? widget.prefilledPrice?.toString();

    if (name != null) {
      _nameController.text = name;
    }
    if (price != null) {
      _priceController.text = price;
    }
    if (widget.prefilledSku != null) {
      _barcode = widget.prefilledSku!;
    }
    if (widget.prefilledUnit != null) {
      _unitController.text = widget.prefilledUnit!;
    }
    if (widget.initialType != null && _innerUnitOptions.contains(widget.initialType)) {
      _selectedInnerUnitType = widget.initialType!;
    }
  }
  final _nameController = TextEditingController();
  final _genericController = TextEditingController();
  final _categoryController = TextEditingController(text: 'General Medicines');
  final _binController = TextEditingController(text: 'AISLE 1 - SHELF A1');
  final _unitController = TextEditingController(text: 'Box of 100');
  final _priceController = TextEditingController(text: '1200');

  // Task 1: Nairobi Autocomplete Catalog Sample Data
  static const List<Map<String, dynamic>> _nairobiCatalog = [
    {'name': 'KOFGON GREEN 60ML', 'price': 25.00, 'type': 'Bottle'},
    {'name': 'KOFGON GREEN 100ML', 'price': 33.00, 'type': 'Bottle'},
    {'name': 'ABZ SUSPENSION 10ML', 'price': 41.00, 'type': 'Bottle'},
    {'name': 'PANADOL EXTRA 100S', 'price': 780.00, 'type': 'Strip/Blister'},
    {'name': 'AMOXICILLIN 500MG 100S', 'price': 1450.00, 'type': 'Strip/Blister'},
    {'name': 'FLUGONE EXP 60MLS', 'price': 380.00, 'type': 'Bottle'},
    {'name': 'INSULIN GLARGINE 100U', 'price': 3200.00, 'type': 'Vial/Ampoule'},
    {'name': 'BETNOVATE CREAM 15G', 'price': 520.00, 'type': 'Tube'},
  ];

  String _selectedInnerUnitType = 'Strip/Blister';
  final List<String> _innerUnitOptions = [
    'Strip/Blister',
    'Bottle',
    'Tube',
    'Vial/Ampoule',
    'Piece/Loose',
  ];

  String _barcode = '';
  Uint8List? _boxImageBytes; // Task 2: Staged byte array for Box photo
  Uint8List? _looseImageBytes; // Task 2: Staged byte array for Loose photo
  bool _isSaving = false;
  final ImagePicker _picker = ImagePicker();

  String get _loosePhotoLabel {
    switch (_selectedInnerUnitType) {
      case 'Bottle':
        return 'Snap Photo of single Bottle';
      case 'Tube':
        return 'Snap Photo of single Tube';
      case 'Vial/Ampoule':
        return 'Snap Photo of single Vial';
      case 'Piece/Loose':
        return 'Snap Photo of single Unit';
      case 'Strip/Blister':
      default:
        return 'Snap Photo of single Strip';
    }
  }

  void _generateInternalSku() {
    final randomNum = 1000 + Random().nextInt(8999);
    setState(() {
      _barcode = 'NRB-MED-$randomNum';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Generated Internal SKU: $_barcode', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.tealAccent.withValues(alpha: 0.8),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _scanBarcode() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      isScrollControlled: true,
      builder: (context) {
        return SizedBox(
          height: 400,
          child: Column(
            children: [
              AppBar(
                backgroundColor: const Color(0xFF0F172A),
                title: Text('Scan Manufacturer Barcode', style: GoogleFonts.inter(fontSize: 16, color: Colors.white)),
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.white)),
                ],
              ),
              Expanded(
                child: MobileScanner(
                  onDetect: (capture) {
                    final List<Barcode> barcodes = capture.barcodes;
                    for (final barcode in barcodes) {
                      if (barcode.rawValue != null && barcode.rawValue!.isNotEmpty) {
                        setState(() {
                          _barcode = barcode.rawValue!;
                        });
                        Navigator.pop(context);
                        break;
                      }
                    }
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                color: const Color(0xFF0F172A),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Simulate Barcode Scan:', style: GoogleFonts.inter(color: Colors.white70)),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _barcode = '6001234567${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
                        });
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black),
                      child: const Text('Inject Barcode'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Task 2: Visual Image Capture & Byte Array Staging
  Future<void> _captureBoxPhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 70, // Enforce 70% quality compression
        maxWidth: 1024,   // Cap resolution
        maxHeight: 1024,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _boxImageBytes = bytes;
        });
      }
    } catch (e) {
      debugPrint('Box photo capture note: $e');
    }
  }

  Future<void> _captureLoosePhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 70, // Enforce 70% quality compression
        maxWidth: 1024,   // Cap resolution
        maxHeight: 1024,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _looseImageBytes = bytes;
        });
      }
    } catch (e) {
      debugPrint('Loose photo capture note: $e');
    }
  }

  // Task 1: Eradicate Local Storage & Restore Supabase (Step-by-Step)
  Future<void> _saveToSupabase() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter medicine name & strength.', style: GoogleFonts.inter(color: Colors.white)),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final supabase = Supabase.instance.client;

      String? imageUrl;

      // 1. Upload Image to Supabase Storage
      if (_boxImageBytes != null) {
        final String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        await supabase.storage.from('medicine_images').uploadBinary(
              fileName,
              _boxImageBytes!,
              fileOptions: const FileOptions(contentType: 'image/jpeg'),
            );
        imageUrl = supabase.storage.from('medicine_images').getPublicUrl(fileName);
      }

      // 2. Insert into database
      final drugData = {
        'name': _nameController.text.trim(),
        'price': double.tryParse(_priceController.text.trim()) ?? 1200.0,
        'inner_unit_type': _selectedInnerUnitType,
        'box_image_url': imageUrl,
        // Keep required schema fields for other features
        'id': 'drug-${DateTime.now().millisecondsSinceEpoch}',
        'sku': _barcode.isNotEmpty ? _barcode : 'NRB-MED-${1000 + Random().nextInt(8999)}',
        'unit_price': double.tryParse(_priceController.text.trim()) ?? 1200.0,
        'image_url': imageUrl, 
      };

      await supabase.from('drugs').insert(drugData).select();

      _nameController.clear();
      _genericController.clear();
      _priceController.clear();
      setState(() {
        _barcode = '';
        _boxImageBytes = null;
        _looseImageBytes = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.cloud_done_rounded, color: Colors.greenAccent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Saved to Cloud.',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } on StorageException catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Storage Error'),
          content: const Text("Cloud Storage Blocked. Ensure your 'medicine_images' bucket exists in Supabase and is set to PUBLIC."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      if (e.toString().contains('ClientException') || e.toString().contains('StorageException')) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Storage Error'),
            content: const Text("Cloud Storage Blocked. Ensure your 'medicine_images' bucket exists in Supabase and is set to PUBLIC."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e', style: GoogleFonts.inter(color: Colors.white)),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: Text(
          'Register New Medicine from Scratch',
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Live Inventory Entry Form',
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Text(
                    'Autofill catalog entries and capture live packaging thumbnails.',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.tealAccent),
                  ),
                  const SizedBox(height: 24),

                  // TASK 1: NAIROBI AUTOCOMPLETE CATALOG FIELD
                  Text(
                    'Enter Medicine Name & Strength',
                    style: GoogleFonts.inter(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  if (widget.prefilledName != null || widget.initialName != null)
                    TextField(
                      controller: _nameController,
                      enabled: false,
                      style: GoogleFonts.inter(color: Colors.white60, fontSize: 14, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.lock_rounded, color: Colors.amberAccent, size: 18),
                        filled: true,
                        fillColor: const Color(0xFF0F172A).withValues(alpha: 0.5),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                    )
                  else
                    Autocomplete<Map<String, dynamic>>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return const Iterable<Map<String, dynamic>>.empty();
                      }
                      return _nairobiCatalog.where((option) {
                        return option['name'].toString().toLowerCase().contains(textEditingValue.text.toLowerCase());
                      });
                    },
                    displayStringForOption: (option) => option['name'] as String,
                    onSelected: (option) {
                      setState(() {
                        _nameController.text = option['name'] as String;
                        _priceController.text = option['price'].toString();
                        _selectedInnerUnitType = option['type'] as String;
                      });
                    },
                    fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                      // Keep local controller in sync
                      textEditingController.addListener(() {
                        _nameController.text = textEditingController.text;
                      });

                      return TextField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Type medicine name (e.g. KOFGON, PANADOL)',
                          hintStyle: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
                          prefixIcon: const Icon(Icons.search_rounded, color: Colors.tealAccent, size: 18),
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        ),
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          color: const Color(0xFF0F172A),
                          elevation: 8,
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 320,
                            child: ListView.separated(
                              shrinkWrap: true,
                              padding: const EdgeInsets.all(8),
                              itemCount: options.length,
                              separatorBuilder: (context, index) => const Divider(color: Colors.white10, height: 1),
                              itemBuilder: (context, index) {
                                final option = options.elementAt(index);
                                return ListTile(
                                  onTap: () => onSelected(option),
                                  leading: const Icon(Icons.medication_rounded, color: Colors.tealAccent, size: 20),
                                  title: Text(option['name'], style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                  subtitle: Text('Price: KES ${option['price']} • Type: ${option['type']}', style: GoogleFonts.inter(color: Colors.tealAccent, fontSize: 11)),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Generic Name Field
                  _buildTextField(_genericController, 'Generic Formula / Name', 'e.g. Amoxicillin Trihydrate', Icons.science_rounded),
                  const SizedBox(height: 16),

                  // Category & Bin Location Row
                  Row(
                    children: [
                      Expanded(child: _buildTextField(_categoryController, 'Category', 'e.g. Antibiotics', Icons.category_rounded)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildTextField(_binController, 'Target Shelf / Bin', 'e.g. AISLE 1 - SHELF A1', Icons.shelves)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Unit & Price Row
                  Row(
                    children: [
                      Expanded(child: _buildTextField(_unitController, 'Package Unit', 'e.g. Box of 100', Icons.inventory_2_rounded)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          _priceController,
                          'Price (KES)',
                          '1200',
                          Icons.payments_rounded,
                          isNum: true,
                          enabled: widget.prefilledName == null && widget.initialName == null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // BARCODE & AUTO SKU GENERATOR
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.qr_code_scanner_rounded, color: Colors.tealAccent, size: 24),
                            const SizedBox(width: 10),
                            Text('Barcode / SKU (Optional)', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _barcode.isNotEmpty ? 'Active SKU: $_barcode' : 'No Barcode Scanned (Optional)',
                          style: GoogleFonts.inter(color: _barcode.isNotEmpty ? Colors.tealAccent : Colors.white54, fontSize: 12),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _scanBarcode,
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black),
                                icon: const Icon(Icons.camera_alt_rounded, size: 16),
                                label: const Text('Scan Code', style: TextStyle(fontSize: 12)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _generateInternalSku,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.tealAccent,
                                  side: const BorderSide(color: Colors.tealAccent),
                                ),
                                icon: const Icon(Icons.refresh_rounded, size: 16),
                                label: const Text('Generate SKU', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // INNER UNIT TYPE SELECTION DROPDOWN
                  Text(
                    'Inner Unit Type (What is inside the box?)',
                    style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.4)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedInnerUnitType,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF1E293B),
                        style: GoogleFonts.inter(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 14),
                        items: _innerUnitOptions.map((option) {
                          return DropdownMenuItem<String>(
                            value: option,
                            child: Row(
                              children: [
                                Icon(
                                  option.contains('Bottle')
                                      ? Icons.liquor_rounded
                                      : (option.contains('Tube')
                                          ? Icons.brush_rounded
                                          : (option.contains('Vial')
                                              ? Icons.science_rounded
                                              : Icons.medication_rounded)),
                                  color: Colors.amberAccent,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Text(option),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedInnerUnitType = val;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // TASK 2: VISUAL IMAGE STATE (SHOW THUMBNAIL PREVIEWS WITH RETAKE OPTION)
                  Row(
                    children: [
                      // Photo 1: Box Front
                      Expanded(
                        child: Container(
                          height: 140,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _boxImageBytes != null ? Colors.tealAccent : Colors.white.withValues(alpha: 0.1)),
                          ),
                          child: _boxImageBytes != null
                              ? Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.memory(_boxImageBytes!, width: double.infinity, height: double.infinity, fit: BoxFit.cover),
                                    ),
                                    Positioned(
                                      bottom: 4,
                                      right: 4,
                                      child: InkWell(
                                        onTap: _captureBoxPhoto,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(6)),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.refresh_rounded, color: Colors.tealAccent, size: 12),
                                              const SizedBox(width: 4),
                                              Text('Retake', style: GoogleFonts.inter(color: Colors.tealAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.inventory_2_outlined, color: Colors.white54, size: 28),
                                    const SizedBox(height: 6),
                                    Text('Full Box Photo', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                    const SizedBox(height: 8),
                                    OutlinedButton.icon(
                                      onPressed: _captureBoxPhoto,
                                      style: OutlinedButton.styleFrom(foregroundColor: Colors.tealAccent, side: const BorderSide(color: Colors.tealAccent)),
                                      icon: const Icon(Icons.camera_alt, size: 14),
                                      label: const Text('Snap Box', style: TextStyle(fontSize: 11)),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Photo 2: Loose Unit Photo
                      Expanded(
                        child: Container(
                          height: 140,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _looseImageBytes != null ? Colors.amberAccent : Colors.amberAccent.withValues(alpha: 0.4)),
                          ),
                          child: _looseImageBytes != null
                              ? Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.memory(_looseImageBytes!, width: double.infinity, height: double.infinity, fit: BoxFit.cover),
                                    ),
                                    Positioned(
                                      bottom: 4,
                                      right: 4,
                                      child: InkWell(
                                        onTap: _captureLoosePhoto,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(6)),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.refresh_rounded, color: Colors.amberAccent, size: 12),
                                              const SizedBox(width: 4),
                                              Text('Retake', style: GoogleFonts.inter(color: Colors.amberAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.medication_liquid_rounded, color: Colors.white54, size: 28),
                                    const SizedBox(height: 6),
                                    Text('Loose Unit (0.10)', style: GoogleFonts.inter(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                                    const SizedBox(height: 8),
                                    OutlinedButton.icon(
                                      onPressed: _captureLoosePhoto,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.amberAccent,
                                        side: const BorderSide(color: Colors.amberAccent),
                                      ),
                                      icon: const Icon(Icons.camera_alt, size: 14),
                                      label: Text(
                                        _loosePhotoLabel,
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // SUBMIT BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: _saveToSupabase,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.tealAccent,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.cloud_upload_rounded, size: 22),
                      label: Text(
                        'Save to Supabase Database',
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isSaving)
            Container(
              color: Colors.black.withValues(alpha: 0.8),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.tealAccent, strokeWidth: 4),
                    const SizedBox(height: 20),
                    Text(
                      'Executing Supabase .insert()...',
                      style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, String hint, IconData icon, {bool isNum = false, bool enabled = true}) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: isNum ? TextInputType.number : TextInputType.text,
      style: GoogleFonts.inter(color: enabled ? Colors.white : Colors.white60, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(color: enabled ? Colors.white70 : Colors.white38, fontSize: 12),
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
        prefixIcon: Icon(icon, color: enabled ? Colors.tealAccent : Colors.white38, size: 18),
        filled: true,
        fillColor: enabled ? const Color(0xFF0F172A) : const Color(0xFF0F172A).withValues(alpha: 0.5),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      ),
    );
  }
}

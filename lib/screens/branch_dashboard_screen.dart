import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/ai_copilot_sheet.dart';
import '../widgets/leave_application_form.dart';
import 'kisumu_in_transit_screen.dart';
import 'etims_workspace_screen.dart';
import 'procurement_lpo_screen.dart';

class BranchDashboardScreen extends StatefulWidget {
  const BranchDashboardScreen({super.key});

  @override
  State<BranchDashboardScreen> createState() => _BranchDashboardScreenState();
}

class _BranchDashboardScreenState extends State<BranchDashboardScreen> {
  bool _isLoading = true;
  double _todayRevenue = 0.0;
  int _lowStockItems = 0;
  int _pendingOrders = 0;
  List<Map<String, dynamic>> _transactions = [];
  List<FlSpot> _chartSpots = [];
  
  final TextEditingController _reqItemController = TextEditingController();
  final TextEditingController _reqQtyController = TextEditingController();
  List<Map<String, dynamic>> _myRequisitions = [];
  List<Map<String, dynamic>> _liveStock = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final db = Supabase.instance.client;
      // Get branch
      final branchRes = await db.from('branches').select().limit(1);
      final branchId = (branchRes as List).isNotEmpty ? branchRes[0]['id'] as String : null;

      if (branchId == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Fetch today's transactions for revenue
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day).toIso8601String();
      
      final txRes = await db.from('transactions')
          .select('*, drugs(name)')
          .eq('branch_id', branchId)
          .order('transaction_date', ascending: false);
      
      final allTx = txRes as List<dynamic>;
      
      double todayRev = 0.0;
      List<Map<String, dynamic>> recentTx = [];
      
      // Calculate chart data (last 7 days)
      Map<int, double> dailySales = {for (var i = 0; i < 7; i++) i: 0.0};
      final now = DateTime.now();

      for (var tx in allTx) {
        final date = DateTime.parse(tx['transaction_date'] as String);
        final amount = (tx['total_amount'] as num).toDouble();
        final type = tx['transaction_type'] as String;
        
        if (type == 'sale') {
          if (date.isAfter(DateTime.parse(startOfDay))) {
            todayRev += amount;
          }
          final diff = now.difference(date).inDays;
          if (diff >= 0 && diff < 7) {
            dailySales[6 - diff] = (dailySales[6 - diff] ?? 0.0) + amount;
          }
        }
        
        if (recentTx.length < 5) {
           final drugName = tx['drugs'] != null ? tx['drugs']['name'] : 'Unknown';
           recentTx.add({
             'name': drugName,
             'qty': '${tx['quantity']} Units',
             'time': '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
             'amount': type == 'sale' ? '+ KES ${amount.toStringAsFixed(0)}' : '- KES ${amount.toStringAsFixed(0)}',
           });
        }
      }

      List<FlSpot> spots = [];
      for (int i = 0; i < 7; i++) {
        spots.add(FlSpot(i.toDouble(), (dailySales[i] ?? 0.0) / 1000.0)); // In thousands
      }

      // Fetch low stock items from drugs directly since there is no inventory table and min_threshold
      final invRes = await db.from('drugs')
          .select('id, name, quantity_in_stock, warehouse_quantity, shelf_quantity');
          
      int lowStockCount = 0;
      for (var inv in (invRes as List<dynamic>)) {
         final qty = (inv['quantity_in_stock'] as num?)?.toInt() ?? 0;
         // Hardcoded threshold since min_threshold doesn't exist
         if (qty < 20) {
           lowStockCount++;
         }
      }

      // Fetch pending orders
      final poRes = await db.from('purchase_orders')
          .select('id')
          .eq('branch_id', branchId)
          .eq('status', 'draft');
          
      final pendingCount = (poRes as List).length;

      // Fetch active internal requisitions
      final reqRes = await db.from('internal_requisitions')
          .select()
          .eq('requested_by_role', 'Pharmacist')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _todayRevenue = todayRev;
          _lowStockItems = lowStockCount;
          _pendingOrders = pendingCount;
          _transactions = recentTx;
          _chartSpots = spots;
          _myRequisitions = List<Map<String, dynamic>>.from(reqRes as List);
          _liveStock = List<Map<String, dynamic>>.from(invRes as List);
          _isLoading = false;
        });
      }
    } catch (e, st) {
      debugPrint('Branch Dashboard Live Data Error: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Failed to load live data: $e'), backgroundColor: Colors.redAccent)
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _submitRequisition() async {
    if (_reqItemController.text.isEmpty || _reqQtyController.text.isEmpty) return;
    
    final qty = double.tryParse(_reqQtyController.text) ?? 0.0;
    if (qty <= 0) return;

    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.from('internal_requisitions').insert({
        'item_name': _reqItemController.text,
        'quantity_requested': qty,
        'status': 'Pending',
        'requested_by_role': 'Pharmacist'
      });
      _reqItemController.clear();
      _reqQtyController.clear();
      await _loadDashboardData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Requisition submitted to Warehouse', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
        setState(() => _isLoading = false);
      }
    }
  }

  void _openMedicineSelectorModal() {
    String search = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = _liveStock.where((d) {
              final name = (d['name'] ?? '').toString().toLowerCase();
              final generic = (d['generic_name'] ?? '').toString().toLowerCase();
              final brand = (d['brand_name'] ?? '').toString().toLowerCase();
              final q = search.toLowerCase();
              return name.contains(q) || generic.contains(q) || brand.contains(q);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Select Registered Medicine (Supabase Catalog)',
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                    TextField(
                    onChanged: (v) => setModalState(() => search = v),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search medicines by brand or formula...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      prefixIcon: const Icon(Icons.search, color: Colors.tealAccent),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => Divider(color: Colors.white.withValues(alpha: 0.05)),
                      itemBuilder: (context, idx) {
                        final drug = filtered[idx];
                        final name = drug['name'] ?? drug['brand_name'] ?? 'Medicine';
                        final generic = drug['generic_name'] ?? '';
                        final stock = drug['quantity_in_stock'] ?? drug['shelf_quantity'] ?? 0;

                        return ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.tealAccent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.medication_rounded, color: Colors.tealAccent, size: 20),
                          ),
                          title: Text(name, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: Text(generic.isNotEmpty ? generic : 'In Stock: $stock Units', style: GoogleFonts.inter(color: Colors.white54, fontSize: 11)),
                          trailing: const Icon(Icons.add_circle_outline, color: Colors.tealAccent, size: 22),
                          onTap: () {
                            setState(() {
                              _reqItemController.text = name;
                            });
                            Navigator.pop(ctx);
                          },
                        );
                      },
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      floatingActionButton: FloatingActionButton(
        onPressed: () => AiCopilotSheet.show(context),
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.auto_awesome, color: Colors.white),
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator(color: Colors.tealAccent))
        : SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 480;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Branch Dashboard',
                        style: GoogleFonts.inter(
                          fontSize: isCompact ? 18 : 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCompact)
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert_rounded, color: Colors.white70),
                        color: const Color(0xFF1E293B),
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(
                            value: 'procurement',
                            child: Row(
                              children: [
                                Icon(Icons.local_shipping_rounded, color: Colors.blueAccent, size: 18),
                                SizedBox(width: 8),
                                Text('Procurement & LPO Hub', style: TextStyle(color: Colors.white, fontSize: 13)),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'etims',
                            child: Row(
                              children: [
                                Icon(Icons.qr_code_scanner_rounded, color: Colors.tealAccent, size: 18),
                                SizedBox(width: 8),
                                Text('KRA eTIMS e-Invoicing', style: TextStyle(color: Colors.white, fontSize: 13)),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'leave',
                            child: Row(
                              children: [
                                Icon(Icons.beach_access, color: Colors.amberAccent, size: 18),
                                SizedBox(width: 8),
                                Text('Request Leave', style: TextStyle(color: Colors.white, fontSize: 13)),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'refresh',
                            child: Row(
                              children: [
                                Icon(Icons.refresh_rounded, color: Colors.white70, size: 18),
                                SizedBox(width: 8),
                                Text('Refresh Dashboard', style: TextStyle(color: Colors.white, fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                        onSelected: (val) {
                          if (val == 'procurement') {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const ProcurementLpoScreen()));
                          } else if (val == 'etims') {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const ETIMSWorkspaceScreen()));
                          } else if (val == 'leave') {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) => Padding(
                                padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                                child: const LeaveApplicationForm(),
                              ),
                            );
                          } else if (val == 'refresh') {
                            _loadDashboardData();
                          }
                        },
                      )
                    else
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.beach_access, color: Colors.blueAccent),
                            tooltip: 'Request Leave',
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (context) => Padding(
                                  padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                                  child: const LeaveApplicationForm(),
                                ),
                              );
                            },
                          ),
                          IconButton(
                            tooltip: 'Procurement & LPO Hub',
                            icon: const Icon(Icons.local_shipping_rounded, color: Colors.blueAccent),
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const ProcurementLpoScreen()));
                            },
                          ),
                          IconButton(
                            tooltip: 'KRA eTIMS e-Invoicing',
                            icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.tealAccent),
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const ETIMSWorkspaceScreen()));
                            },
                          ),
                          IconButton(
                            onPressed: _loadDashboardData,
                            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
                            tooltip: 'Refresh Dashboard',
                          ),
                        ],
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),

            // Live In-Transit Dispatch Alert Card (Only displays if active dispatches exist)
            if (_myRequisitions.any((r) => r['status']?.toString().toLowerCase() == 'in_transit'))
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 18),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0D9488), Color(0xFF1E3A8A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.4)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.tealAccent.withValues(alpha: 0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.5)),
                          ),
                          child: const Icon(Icons.local_shipping_rounded, color: Colors.tealAccent, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Active Incoming Stock Transfer En Route',
                                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Inter-branch requisition verified and currently in transit.',
                                style: GoogleFonts.inter(color: Colors.tealAccent, fontSize: 11, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const KisumuInTransitScreen()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.tealAccent,
                          foregroundColor: const Color(0xFF0F172A),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 3,
                        ),
                        icon: const Icon(Icons.radar_rounded, size: 16),
                        label: Text(
                          'Track Medicines En Route',
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 800) {
                  return Row(
                    children: [
                      Expanded(
                        child: _buildKPICard(
                          'Today\'s Branch Revenue',
                          'KES ${_todayRevenue.toStringAsFixed(0)}',
                          Icons.arrow_upward,
                          Colors.green,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildKPICard(
                          'Low Stock Alerts',
                          '$_lowStockItems Items',
                          Icons.warning,
                          Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildKPICard(
                          'Pending Online Orders',
                          '$_pendingOrders Orders',
                          Icons.shopping_cart,
                          Colors.blue,
                        ),
                      ),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      _buildKPICard(
                        'Today\'s Branch Revenue',
                        'KES ${_todayRevenue.toStringAsFixed(0)}',
                        Icons.arrow_upward,
                        Colors.green,
                      ),
                      const SizedBox(height: 16),
                      _buildKPICard(
                        'Low Stock Alerts',
                        '$_lowStockItems Items',
                        Icons.warning,
                        Colors.orange,
                      ),
                      const SizedBox(height: 16),
                      _buildKPICard(
                        'Pending Online Orders',
                        '$_pendingOrders Orders',
                        Icons.shopping_cart,
                        Colors.blue,
                      ),
                    ],
                  );
                }
              },
            ),
            const SizedBox(height: 24),
            _buildInternalRequisitionModule(),
            const SizedBox(height: 24),
            _buildLiveSplitInventoryView(),
            const SizedBox(height: 24),
            _buildChartCard(),
            const SizedBox(height: 24),
            _buildTransactionsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildInternalRequisitionModule() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text('Internal Stock Requisition & Transfer', style: GoogleFonts.inter(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const KisumuInTransitScreen()));
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.tealAccent,
                  side: const BorderSide(color: Colors.tealAccent),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.local_shipping_rounded, size: 16),
                label: Text('Kisumu Transit Radar', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Form(
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 240,
                  child: TextField(
                    controller: _reqItemController,
                    readOnly: true,
                    onTap: _openMedicineSelectorModal,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Select Registered Medicine',
                      hintText: 'Tap to pick from 782 SKUs',
                      labelStyle: const TextStyle(color: Colors.tealAccent),
                      hintStyle: const TextStyle(color: Colors.white38),
                      prefixIcon: const Icon(Icons.medication_rounded, color: Colors.tealAccent, size: 20),
                      suffixIcon: const Icon(Icons.arrow_drop_down, color: Colors.tealAccent),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.tealAccent.withValues(alpha: 0.3))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.tealAccent)),
                    ),
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: TextField(
                    controller: _reqQtyController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Quantity',
                      labelStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.tealAccent)),
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _submitRequisition,
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text('Request from Warehouse'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.tealAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          if (_myRequisitions.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Active Requests', style: GoogleFonts.inter(color: Colors.white70, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _myRequisitions.length,
              separatorBuilder: (_, _) => Divider(color: Colors.white.withValues(alpha: 0.05)),
              itemBuilder: (context, index) {
                final req = _myRequisitions[index];
                final status = req['status'] ?? 'Pending';
                final isApproved = status == 'Completed';
                final isRejected = status == 'Rejected';
                
                Color statusColor = Colors.orangeAccent;
                if (isApproved) statusColor = Colors.greenAccent;
                if (isRejected) statusColor = Colors.redAccent;

                return ListTile(
                  leading: Icon(isApproved ? Icons.check_circle : (isRejected ? Icons.cancel : Icons.pending), color: statusColor),
                  title: Text(req['item_name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text('Requested: ${req['quantity_requested']}', style: const TextStyle(color: Colors.white54)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(status, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLiveSplitInventoryView() {
    final filteredStock = _liveStock.where((s) {
      final name = (s['name'] ?? '').toLowerCase();
      final brand = (s['brand_name'] ?? '').toLowerCase();
      final generic = (s['generic_name'] ?? '').toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || brand.contains(query) || generic.contains(query);
    }).toList();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Live Stock Locations', style: GoogleFonts.inter(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search by brand or generic name...',
              hintStyle: const TextStyle(color: Colors.white54),
              prefixIcon: const Icon(Icons.search, color: Colors.white54),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.tealAccent.withValues(alpha: 0.3))),
              focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.tealAccent)),
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
          const SizedBox(height: 16),
          if (filteredStock.isEmpty)
            Center(child: Text('No stock data available', style: GoogleFonts.inter(color: Colors.white54)))
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredStock.length,
              itemBuilder: (context, index) {
                final stock = filteredStock[index];
                final hasImage = stock['image_url'] != null && stock['image_url'].toString().isNotEmpty;
                final brandName = stock['brand_name'] ?? stock['name'] ?? 'Unknown';
                final genericName = stock['generic_name'] ?? '';
                final dosageForm = stock['dosage_form'] ?? '';
                final displayName = genericName.isNotEmpty ? '$brandName ($genericName $dosageForm)'.trim() : brandName;
                
                return Column(
                  children: [
                    ListTile(
                      leading: hasImage
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                stock['image_url'],
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, err, stack) => const Icon(Icons.medication_liquid_rounded, color: Colors.tealAccent, size: 50),
                              ),
                            )
                          : const Icon(Icons.medication_liquid_rounded, color: Colors.tealAccent, size: 50),
                      title: Text(displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      subtitle: Wrap(
                        spacing: 16,
                        runSpacing: 4,
                        children: [
                          Text('On Shelf: ${stock['shelf_quantity'] ?? 0}', style: const TextStyle(color: Colors.white70)),
                          Text('In Warehouse: ${stock['warehouse_quantity'] ?? 0}', style: const TextStyle(color: Colors.white70)),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit, color: Colors.amberAccent),
                        onPressed: () => _showInitialStockDialog(stock),
                      ),
                    ),
                    if (index < filteredStock.length - 1)
                      Divider(color: Colors.white.withValues(alpha: 0.05)),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  void _showInitialStockDialog(Map<String, dynamic> stock) {
    final pharmController = TextEditingController(text: (stock['shelf_quantity'] ?? 0).toString());
    final storeController = TextEditingController(text: (stock['warehouse_quantity'] ?? 0).toString());

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: Text('Initial Stock Audit: ${stock['name']}', style: const TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: pharmController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Quantity on Shelf',
                  labelStyle: const TextStyle(color: Colors.white54),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.tealAccent.withValues(alpha: 0.3))),
                  focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.tealAccent)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: storeController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Quantity in Warehouse',
                  labelStyle: const TextStyle(color: Colors.white54),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.tealAccent.withValues(alpha: 0.3))),
                  focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.tealAccent)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final db = Supabase.instance.client;
                  final pharmQty = int.tryParse(pharmController.text) ?? 0;
                  final storeQty = int.tryParse(storeController.text) ?? 0;
                  
                  await db.from('drugs').update({
                    'shelf_quantity': pharmQty,
                    'warehouse_quantity': storeQty,
                  }).eq('id', stock['id']);
                  
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    _loadDashboardData(); // Refresh data
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Stock updated successfully'), backgroundColor: Colors.green));
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error updating stock: $e'), backgroundColor: Colors.redAccent));
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildKPICard(String title, String value, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard() {
    // Find max Y for the chart dynamically
    double maxY = 10;
    for (var spot in _chartSpots) {
      if (spot.y > maxY) maxY = spot.y;
    }
    maxY = (maxY * 1.2).ceilToDouble(); // Add 20% headroom

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Branch Sales — Last 7 Days (KES \'000)',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 300,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  horizontalInterval: maxY / 5 > 0 ? maxY / 5 : 1,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.white.withValues(alpha: 0.05),
                      strokeWidth: 1,
                    );
                  },
                  getDrawingVerticalLine: (value) {
                    return FlLine(
                      color: Colors.white.withValues(alpha: 0.05),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final days = List.generate(7, (i) {
                          final date = DateTime.now().subtract(Duration(days: 6 - i));
                          final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                          return dayNames[date.weekday - 1];
                        });
                        if (value.toInt() >= 0 && value.toInt() < days.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              days[value.toInt()],
                              style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 12),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: maxY / 5 > 0 ? maxY / 5 : 1,
                      reservedSize: 42,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}K',
                          style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 12),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: 6,
                minY: 0,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: _chartSpots.isEmpty ? List.generate(7, (i) => FlSpot(i.toDouble(), 0)) : _chartSpots,
                    isCurved: true,
                    color: Colors.tealAccent,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.tealAccent.withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Transactions',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _transactions.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32.0),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.receipt_long, color: Colors.white38, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          'No recent transactions',
                          style: GoogleFonts.inter(color: Colors.white54, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _transactions.length,
                  separatorBuilder: (context, index) => Divider(color: Colors.grey[800]),
                  itemBuilder: (context, index) {
                    final tx = _transactions[index];
                    final isPositive = tx['amount'].toString().startsWith('+');
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isPositive ? Colors.tealAccent.withValues(alpha: 0.1) : Colors.redAccent.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isPositive ? Icons.receipt_long : Icons.inventory_2_outlined, 
                          color: isPositive ? Colors.tealAccent : Colors.redAccent
                        ),
                      ),
                      title: Text(
                        tx['name']!,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        '${tx['qty']} • ${tx['time']}',
                        style: GoogleFonts.inter(
                          color: Colors.grey[400],
                          fontSize: 12,
                        ),
                      ),
                      trailing: Text(
                        tx['amount']!,
                        style: GoogleFonts.inter(
                          color: isPositive ? Colors.greenAccent : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }
}

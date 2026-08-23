import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';

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
          .select('name, quantity_in_stock, store_quantity, pharmacy_quantity');
          
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.tealAccent))
        : SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Branch Dashboard',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  onPressed: _loadDashboardData,
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
                  tooltip: 'Refresh Dashboard',
                )
              ],
            ),
            const SizedBox(height: 24),
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
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Internal Stock Requisition', style: GoogleFonts.inter(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _reqItemController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Item Name',
                    labelStyle: const TextStyle(color: Colors.white54),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.tealAccent.withOpacity(0.3))),
                    focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.tealAccent)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _reqQtyController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Quantity Needed',
                    labelStyle: const TextStyle(color: Colors.white54),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.tealAccent.withOpacity(0.3))),
                    focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.tealAccent)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _submitRequisition,
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text('Request from Warehouse'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.tealAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                ),
              ),
            ],
          ),
          if (_myRequisitions.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Active Requests', style: GoogleFonts.inter(color: Colors.white70, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _myRequisitions.length,
              separatorBuilder: (_, __) => Divider(color: Colors.white.withOpacity(0.05)),
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
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
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
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Live Stock Locations', style: GoogleFonts.inter(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (_liveStock.isEmpty)
            Center(child: Text('No stock data available', style: GoogleFonts.inter(color: Colors.white54)))
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _liveStock.length,
              separatorBuilder: (_, __) => Divider(color: Colors.white.withOpacity(0.05)),
              itemBuilder: (context, index) {
                final stock = _liveStock[index];
                return ListTile(
                  leading: const Icon(Icons.medication_liquid_rounded, color: Colors.tealAccent),
                  title: Text(stock['name'] ?? 'Unknown', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Row(
                    children: [
                      Text('On Shelf (Pharmacy): ${stock['pharmacy_quantity'] ?? 0}', style: const TextStyle(color: Colors.white70)),
                      const SizedBox(width: 16),
                      Text('In Warehouse (Store): ${stock['store_quantity'] ?? 0}', style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
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
              color: iconColor.withOpacity(0.1),
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
                      color: Colors.white.withOpacity(0.05),
                      strokeWidth: 1,
                    );
                  },
                  getDrawingVerticalLine: (value) {
                    return FlLine(
                      color: Colors.white.withOpacity(0.05),
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
                      color: Colors.tealAccent.withOpacity(0.1),
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
                          color: isPositive ? Colors.tealAccent.withOpacity(0.1) : Colors.redAccent.withOpacity(0.1),
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

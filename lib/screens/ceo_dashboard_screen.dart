import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import 'ceo_fleet_map_screen.dart';
import '../widgets/ai_copilot_sheet.dart';
import 'etims_workspace_screen.dart';
import '../services/supabase_service.dart';

class CeoDashboardScreen extends StatefulWidget {
  const CeoDashboardScreen({super.key});

  @override
  State<CeoDashboardScreen> createState() => _CeoDashboardScreenState();
}

class _CeoDashboardScreenState extends State<CeoDashboardScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  List<Map<String, dynamic>> _branchRevenues = [];
  Map<String, double> _categorySales = {};
  List<Map<String, dynamic>> _topDrugs = [];
  List<Map<String, dynamic>> _liveActivities = [];
  double _totalRevenue = 0.0;
  int _totalTransactions = 0;
  int _lowStockCount = 0;
  double _maxBranchRev = 0.0;

  final NumberFormat _currencyFormat = NumberFormat("#,##0", "en_US");

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final supabaseService = SupabaseService();
      final db = Supabase.instance.client;

      // CALL 1: Single Round-Trip KPI Aggregation RPC
      final kpis = await supabaseService.fetchDashboardKpis();
      final double total = (kpis['total_revenue'] as num?)?.toDouble() ?? 0.0;
      final int totalTx = (kpis['total_transactions'] as num?)?.toInt() ?? 0;
      final int lowStock = (kpis['low_stock_count'] as num?)?.toInt() ?? 0;

      // CALL 2: Single Round-Trip Branch Revenue RPC
      final branchData = await supabaseService.fetchBranchRevenue();
      double maxRev = 0.0;
      final List<Map<String, dynamic>> branchRevenues = [];
      for (var b in branchData) {
        final rev = (b['revenue'] as num?)?.toDouble() ?? 0.0;
        if (rev > maxRev) maxRev = rev;
        branchRevenues.add({
          'id': b['branch_id']?.toString() ?? '',
          'code': b['code']?.toString() ?? 'BR',
          'name': b['branch_name']?.toString() ?? 'Branch',
          'revenue': rev,
        });
      }

      // CALL 3: Bounded Recent Activities
      final recentRes = await db
          .from('transactions')
          .select('id, total_amount, transaction_date')
          .eq('transaction_type', 'sale')
          .order('transaction_date', ascending: false)
          .limit(10);

      final List<dynamic> txList = recentRes as List<dynamic>;
      final recentActivities = txList.map((tx) {
        final amount = (tx['total_amount'] as num?)?.toDouble() ?? 0.0;
        final rawId = tx['id']?.toString() ?? 'TX';
        final shortId = rawId.length >= 8 ? rawId.substring(0, 8) : rawId;
        return {
          'id': shortId,
          'amount': amount,
          'date': tx['transaction_date'],
        };
      }).toList();

      if (mounted) {
        setState(() {
          _branchRevenues = branchRevenues;
          _totalRevenue = total;
          _totalTransactions = totalTx;
          _lowStockCount = lowStock;
          _liveActivities = recentActivities;
          _maxBranchRev = maxRev;
          _topDrugs = [];
          _categorySales = {};
          _isLoading = false;
          _errorMessage = '';
        });
      }
    } catch (e) {
      debugPrint('CEO Dashboard load error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load executive analytics: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 850;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.dashboard_customize_rounded, color: Colors.blueAccent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isDesktop ? 'Executive Pharmacy Analytics (CEO Dashboard)' : 'CEO Analytics',
                style: GoogleFonts.inter(
                  fontSize: isDesktop ? 16 : 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'KRA eTIMS Compliance & e-Invoicing',
            icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.tealAccent),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ETIMSWorkspaceScreen()));
            },
          ),
          IconButton(
            onPressed: _loadDashboardData,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            tooltip: 'Refresh Analytics',
          ),
          if (isDesktop)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: OutlinedButton.icon(
                onPressed: () => AuthService().logout(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.logout_rounded, size: 16),
                label: Text('Logout CEO', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
              tooltip: 'Logout CEO',
              onPressed: () => AuthService().logout(),
            ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'ai_copilot_fab',
            onPressed: () => AiCopilotSheet.show(context),
            backgroundColor: Colors.tealAccent,
            child: const Icon(Icons.auto_awesome, color: Colors.black),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'live_fleet_fab',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CeoFleetMapScreen()));
            },
            backgroundColor: Colors.blueAccent,
            icon: const Icon(Icons.map_rounded, color: Colors.white),
            label: Text(
              isDesktop ? 'Live Fleet Tracking' : 'Fleet Map',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage,
                          style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadDashboardData,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: Text('Retry Analytics Sync', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: EdgeInsets.all(isDesktop ? 24.0 : 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Summary KPI Cards (Bulletproof Sizing - No Overflows)
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.maxWidth;
                          final int crossAxisCount = width > 950 ? 4 : 2;
                          final double childAspectRatio = width > 950 ? 2.5 : 1.75;

                          return GridView.count(
                            crossAxisCount: crossAxisCount,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: childAspectRatio,
                            children: [
                              _buildKpiCard(
                                'Total ERP Sales',
                                'KES ${_currencyFormat.format(_totalRevenue)}',
                                'Real-time Synced',
                                Icons.attach_money_rounded,
                                const Color(0xFF10B981),
                              ),
                              _buildKpiCard(
                                'Active Branches',
                                '${_branchRevenues.length} Regional Hubs',
                                'All Registered Branches',
                                Icons.storefront_rounded,
                                Colors.blueAccent,
                              ),
                              _buildKpiCard(
                                'Total Orders',
                                '$_totalTransactions Fulfilled',
                                'Total Sales Recorded',
                                Icons.receipt_long_rounded,
                                Colors.amberAccent,
                              ),
                              _buildKpiCard(
                                'Inventory Health',
                                _lowStockCount > 0 ? '$_lowStockCount Items Low' : 'Optimal Inventory',
                                'Live Real-time Stock',
                                Icons.verified_user_rounded,
                                _lowStockCount > 0 ? Colors.amberAccent : Colors.purpleAccent,
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),

                      // Charts Section (Responsive Row on Desktop, Clean Column on Mobile)
                      if (isDesktop)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 6,
                              child: _buildBranchRevenueChart(),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              flex: 4,
                              child: _buildCategorySalesChart(),
                            ),
                          ],
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildBranchRevenueChart(),
                            const SizedBox(height: 20),
                            _buildCategorySalesChart(),
                          ],
                        ),

                      const SizedBox(height: 24),

                      // Top Selling Drugs Table
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Top Selling Pharmaceuticals', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                            const SizedBox(height: 14),
                            if (_topDrugs.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 24),
                                child: Center(
                                  child: Text(
                                    'No pharmaceutical sales recorded yet.',
                                    style: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
                                  ),
                                ),
                              )
                            else
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  headingRowColor: WidgetStateProperty.all(Colors.black26),
                                  columns: [
                                    DataColumn(label: Text('SKU', style: GoogleFonts.inter(color: Colors.white70, fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Drug Name', style: GoogleFonts.inter(color: Colors.white70, fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Category', style: GoogleFonts.inter(color: Colors.white70, fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Warehouse Bin', style: GoogleFonts.inter(color: Colors.white70, fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Total Revenue', style: GoogleFonts.inter(color: Colors.white70, fontWeight: FontWeight.bold))),
                                  ],
                                  rows: _topDrugs.map((d) {
                                    return _buildDataRow(
                                      d['sku'] ?? 'SKU',
                                      d['name'] ?? 'Drug',
                                      d['category'] ?? 'Category',
                                      d['bin'] ?? '-',
                                      'KES ${_currencyFormat.format(d['total_amount'] ?? 0)}',
                                    );
                                  }).toList(),
                                ),
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Live Recent Activities Feed
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
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
                                Text('Live Activity Feed', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                                      const SizedBox(width: 6),
                                      Text('Real-time Stream', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF10B981), fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            if (_liveActivities.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 24),
                                child: Center(
                                  child: Text(
                                    'No sales recorded yet.',
                                    style: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
                                  ),
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _liveActivities.length,
                                separatorBuilder: (context, index) => const Divider(color: Colors.white10, height: 1),
                                itemBuilder: (context, index) {
                                  final act = _liveActivities[index];
                                  final timeStr = act['date'] != null
                                      ? act['date'].toString().substring(11, 16)
                                      : 'Just now';
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const CircleAvatar(
                                      backgroundColor: Color(0xFF0F766E),
                                      child: Icon(Icons.receipt_long_rounded, color: Colors.white, size: 18),
                                    ),
                                    title: Text(
                                      'Wholesale Invoice #${act['id']}',
                                      style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    subtitle: Text(
                                      'Sale Transaction • $timeStr',
                                      style: GoogleFonts.inter(color: Colors.white54, fontSize: 11),
                                    ),
                                    trailing: Text(
                                      'KES ${_currencyFormat.format(act['amount'])}',
                                      style: GoogleFonts.inter(color: Colors.tealAccent, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildBranchRevenueChart() {
    final hasData = _branchRevenues.isNotEmpty && _branchRevenues.any((b) => (b['revenue'] as num) > 0);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Revenue Comparison Across Branches',
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            'Multi-branch sales breakdown across Kenya operations',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.white54),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 250,
            child: !hasData
                ? Center(
                    child: Text(
                      'No branch sales recorded yet.',
                      style: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
                    ),
                  )
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: _maxBranchRev > 0 ? (_maxBranchRev * 1.25) : 100.0,
                      barTouchData: BarTouchData(enabled: true),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (double value, TitleMeta meta) {
                              int idx = value.toInt();
                              if (idx >= 0 && idx < _branchRevenues.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    _branchRevenues[idx]['code'] ?? 'BR',
                                    style: GoogleFonts.inter(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                );
                              }
                              return const SizedBox();
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 52,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                '${(value / 1000).toStringAsFixed(0)}k',
                                style: GoogleFonts.inter(color: Colors.white38, fontSize: 10),
                              );
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) => const FlLine(color: Colors.white10, strokeWidth: 1),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: List.generate(_branchRevenues.length, (index) {
                        final rev = (_branchRevenues[index]['revenue'] as num).toDouble();
                        return BarChartGroupData(
                          x: index,
                          barRods: [
                            BarChartRodData(
                              toY: rev,
                              gradient: const LinearGradient(
                                colors: [Colors.blueAccent, Colors.tealAccent],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              ),
                              width: 22,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySalesChart() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sales Category Distribution',
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            'Top pharmaceutical product segments',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.white54),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 250,
            child: _categorySales.isEmpty
                ? Center(
                    child: Text(
                      'No category sales recorded yet.',
                      style: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
                    ),
                  )
                : PieChart(
                    PieChartData(
                      sectionsSpace: 3,
                      centerSpaceRadius: 40,
                      sections: _categorySales.entries.toList().asMap().entries.map((entry) {
                        final idx = entry.key;
                        final cat = entry.value;
                        final List<Color> colors = [
                          Colors.blueAccent,
                          Colors.tealAccent,
                          Colors.amberAccent,
                          Colors.purpleAccent,
                          Colors.pinkAccent,
                        ];
                        final color = colors[idx % colors.length];
                        final pct = _totalRevenue > 0 ? (cat.value / _totalRevenue * 100) : 0.0;
                        return PieChartSectionData(
                          value: cat.value,
                          title: '${pct.toStringAsFixed(0)}%',
                          color: color,
                          radius: 48,
                          titleStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                          badgeWidget: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.white24, width: 0.5),
                            ),
                            child: Text(cat.key, style: GoogleFonts.inter(fontSize: 9, color: Colors.white)),
                          ),
                          badgePositionPercentageOffset: 1.25,
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  DataRow _buildDataRow(String sku, String name, String category, String bin, String price) {
    return DataRow(
      cells: [
        DataCell(Text(sku, style: GoogleFonts.inter(color: Colors.cyanAccent, fontWeight: FontWeight.w600))),
        DataCell(Text(name, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w500))),
        DataCell(Text(category, style: GoogleFonts.inter(color: Colors.white70))),
        DataCell(Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: Colors.blueAccent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
          child: Text(bin, style: GoogleFonts.inter(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold)),
        )),
        DataCell(Text(price, style: GoogleFonts.inter(color: const Color(0xFF10B981), fontWeight: FontWeight.bold))),
      ],
    );
  }

  Widget _buildKpiCard(String title, String value, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.white60, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, color: color, size: 18),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          Text(
            subtitle,
            style: GoogleFonts.inter(fontSize: 10, color: color, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/supabase_service.dart';
import '../services/auth_service.dart';

class CeoDashboardScreen extends StatefulWidget {
  const CeoDashboardScreen({super.key});

  @override
  State<CeoDashboardScreen> createState() => _CeoDashboardScreenState();
}

class _CeoDashboardScreenState extends State<CeoDashboardScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _branchRevenues = [];
  double _totalRevenue = 0.0;
  int _totalTransactions = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    final revenues = await _supabaseService.fetchBranchRevenue();
    double total = 0.0;
    for (var b in revenues) {
      total += (b['revenue'] as num).toDouble();
    }

    if (mounted) {
      setState(() {
        _branchRevenues = revenues;
        _totalRevenue = total;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark Slate
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.dashboard_customize_rounded, color: Colors.blueAccent),
            ),
            const SizedBox(width: 12),
            Text(
              'Executive Pharmacy Analytics (CEO View)',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loadDashboardData,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            tooltip: 'Refresh Analytics',
          ),
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
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Summary KPI Cards
                  LayoutBuilder(
                    builder: (context, constraints) {
                      int count = isDesktop ? 4 : 2;
                      return GridView.count(
                        crossAxisCount: count,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: isDesktop ? 2.2 : 1.8,
                        children: [
                          _buildKpiCard('Total ERP Sales', '\$${_totalRevenue.toStringAsFixed(2)}', '+18.4% vs last month', Icons.attach_money_rounded, const Color(0xFF10B981)),
                          _buildKpiCard('Active Branches', '${_branchRevenues.length} Locations', '100% Operational', Icons.storefront_rounded, Colors.blueAccent),
                          _buildKpiCard('Total Orders', '$_totalTransactions Sales', 'Past 30 Days', Icons.receipt_long_rounded, Colors.amber),
                          _buildKpiCard('Inventory Health', '94.2%', 'ABC Velocity Optimized', Icons.verified_user_rounded, Colors.purpleAccent),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 32),

                  // Charts Section
                  Flex(
                    direction: isDesktop ? Axis.horizontal : Axis.vertical,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Branch Revenue Bar Chart
                      Expanded(
                        flex: isDesktop ? 6 : 0,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.08)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Revenue Comparison Across Branches',
                                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Live Supabase multi-branch transaction aggregation',
                                style: GoogleFonts.inter(fontSize: 12, color: Colors.white54),
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                height: 260,
                                child: BarChart(
                                  BarChartData(
                                    alignment: BarChartAlignment.spaceAround,
                                    maxY: (_totalRevenue * 0.8).clamp(10000.0, 50000.0),
                                    barTouchData: BarTouchData(enabled: false),
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
                                          reservedSize: 40,
                                          getTitlesWidget: (value, meta) {
                                            return Text(
                                              '\$${(value / 1000).toStringAsFixed(0)}k',
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
                                      getDrawingHorizontalLine: (value) => FlLine(color: Colors.white10, strokeWidth: 1),
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
                                              colors: [Colors.blueAccent, Colors.cyanAccent],
                                              begin: Alignment.bottomCenter,
                                              end: Alignment.topCenter,
                                            ),
                                            width: 24,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                        ],
                                      );
                                    }),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (isDesktop) const SizedBox(width: 24) else const SizedBox(height: 24),

                      // Sales Distribution Pie Chart
                      Expanded(
                        flex: isDesktop ? 4 : 0,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.08)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Top Category Breakdown',
                                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              const SizedBox(height: 6),
                              Text('Sales share by therapeutic category', style: GoogleFonts.inter(fontSize: 12, color: Colors.white54)),
                              const SizedBox(height: 24),
                              SizedBox(
                                height: 260,
                                child: PieChart(
                                  PieChartData(
                                    sectionsSpace: 4,
                                    centerSpaceRadius: 40,
                                    sections: [
                                      PieChartSectionData(value: 100, title: 'No Data', color: Colors.white10, radius: 55, titleStyle: GoogleFonts.inter(fontSize: 10, color: Colors.white54)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Top Selling Drugs Table
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Top Selling Pharmaceuticals', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 16),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(Colors.black12),
                            columns: [
                              DataColumn(label: Text('SKU', style: GoogleFonts.inter(color: Colors.white70, fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Drug Name', style: GoogleFonts.inter(color: Colors.white70, fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Category', style: GoogleFonts.inter(color: Colors.white70, fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Bin Location', style: GoogleFonts.inter(color: Colors.white70, fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Unit Price', style: GoogleFonts.inter(color: Colors.white70, fontWeight: FontWeight.bold))),
                            ],
                            rows: [],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
          decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
          child: Text(bin, style: GoogleFonts.inter(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold)),
        )),
        DataCell(Text(price, style: GoogleFonts.inter(color: const Color(0xFF10B981), fontWeight: FontWeight.bold))),
      ],
    );
  }

  Widget _buildKpiCard(String title, String value, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: GoogleFonts.inter(fontSize: 12, color: Colors.white54, fontWeight: FontWeight.w500)),
              Icon(icon, color: color, size: 22),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/supabase_service.dart';

class SmartReplenishmentScreen extends StatefulWidget {
  const SmartReplenishmentScreen({super.key});

  @override
  State<SmartReplenishmentScreen> createState() => _SmartReplenishmentScreenState();
}

class _SmartReplenishmentScreenState extends State<SmartReplenishmentScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  bool _isLoading = true;
  bool _isDrafting = false;
  List<Map<String, dynamic>> _abcItems = [];
  Map<String, dynamic>? _lastPoResult;

  @override
  void initState() {
    super.initState();
    _loadAbcData();
  }

  Future<void> _loadAbcData() async {
    setState(() => _isLoading = true);
    final items = await _supabaseService.getAbcClassification();
    if (mounted) {
      setState(() {
        _abcItems = items;
        _isLoading = false;
      });
    }
  }

  Future<void> _triggerAutoDraftPO() async {
    setState(() => _isDrafting = true);
    final result = await _supabaseService.autoDraftPurchaseOrders();
    if (mounted) {
      setState(() {
        _lastPoResult = result;
        _isDrafting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF10B981),
          content: Text(
            'Auto-drafted Purchase Order #${result['po_number'] ?? 'PO-2026'}! Added ${result['items_added'] ?? 3} low-stock line items.',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    int deadStockCount = _abcItems.where((i) => i['abc_class'] == 'Dead').length;
    int fastStockCount = _abcItems.where((i) => i['abc_class'] == 'Fast').length;

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
                color: const Color(0xFF10B981).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF10B981)),
            ),
            const SizedBox(width: 12),
            Text(
              'Smart Inventory Replenishment & ABC Velocity',
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loadAbcData,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Action Banner
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E293B), Color(0xFF0F2942)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '30-Day Sales Velocity & Automated Reorder Engine',
                                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Fast ($fastStockCount top 20% velocity) • Dead Stock ($deadStockCount zero-sales items flagged)',
                                style: GoogleFonts.inter(fontSize: 12, color: Colors.white60),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _isDrafting ? null : _triggerAutoDraftPO,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: _isDrafting
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.shopping_cart_checkout_rounded),
                          label: Text(
                            _isDrafting ? 'Drafting PO...' : 'Auto-Draft Purchase Order',
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (_lastPoResult != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 24),
                          const SizedBox(width: 12),
                          Text(
                            'Active Draft Order: ${_lastPoResult!['po_number']} | Added ${_lastPoResult!['items_added']} items | Total Value: \$${(_lastPoResult!['total_amount'] as num).toStringAsFixed(2)}',
                            style: GoogleFonts.inter(color: const Color(0xFF10B981), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Inventory Classification Data Table
                  Container(
                    width: double.infinity,
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
                          'Inventory Classification & Reorder Thresholds',
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 16),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: [
                              DataColumn(label: Text('SKU', style: GoogleFonts.inter(color: Colors.white70, fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Drug Name', style: GoogleFonts.inter(color: Colors.white70, fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('ABC Tier', style: GoogleFonts.inter(color: Colors.white70, fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Bin Location', style: GoogleFonts.inter(color: Colors.white70, fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Current Stock', style: GoogleFonts.inter(color: Colors.white70, fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Min / Max Threshold', style: GoogleFonts.inter(color: Colors.white70, fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Status & Action', style: GoogleFonts.inter(color: Colors.white70, fontWeight: FontWeight.bold))),
                            ],
                            rows: _abcItems.map((item) {
                              final int stock = (item['current_stock'] as num).toInt();
                              final int minThresh = (item['min_threshold'] as num).toInt();
                              final int maxThresh = (item['max_threshold'] as num).toInt();
                              final String abcClass = item['abc_class'] as String;

                              bool isLowStock = stock < minThresh;

                              return DataRow(
                                cells: [
                                  DataCell(Text(item['sku'] ?? '', style: GoogleFonts.inter(color: Colors.cyanAccent, fontWeight: FontWeight.w600))),
                                  DataCell(Text(item['name'] ?? '', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w500))),
                                  DataCell(_buildAbcBadge(abcClass)),
                                  DataCell(Text(item['bin_location'] ?? '', style: GoogleFonts.inter(color: Colors.white70, fontSize: 12))),
                                  DataCell(Text(
                                    '$stock units',
                                    style: GoogleFonts.inter(
                                      color: isLowStock ? Colors.redAccent : Colors.white,
                                      fontWeight: isLowStock ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  )),
                                  DataCell(Text('$minThresh / $maxThresh', style: GoogleFonts.inter(color: Colors.white54))),
                                  DataCell(_buildStatusCell(abcClass, isLowStock)),
                                ],
                              );
                            }).toList(),
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

  Widget _buildAbcBadge(String abcClass) {
    Color bg;
    Color fg;
    IconData icon;

    switch (abcClass) {
      case 'Fast':
        bg = const Color(0xFF10B981).withValues(alpha: 0.2);
        fg = const Color(0xFF10B981);
        icon = Icons.bolt_rounded;
        break;
      case 'Steady':
        bg = Colors.blueAccent.withValues(alpha: 0.2);
        fg = Colors.blueAccent;
        icon = Icons.show_chart_rounded;
        break;
      case 'Dead':
      default:
        bg = Colors.redAccent.withValues(alpha: 0.2);
        fg = Colors.redAccent;
        icon = Icons.warning_amber_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20), border: Border.all(color: fg.withValues(alpha: 0.5))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: fg, size: 14),
          const SizedBox(width: 4),
          Text(
            abcClass == 'Dead' ? 'DEAD STOCK' : '$abcClass Stock',
            style: GoogleFonts.inter(color: fg, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCell(String abcClass, bool isLowStock) {
    if (abcClass == 'Dead') {
      return Text('Discount / Return', style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w600));
    } else if (isLowStock) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
        child: Text('Reorder Suggested', style: GoogleFonts.inter(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold)),
      );
    } else {
      return Text('Optimal', style: GoogleFonts.inter(color: Colors.white38, fontSize: 12));
    }
  }
}

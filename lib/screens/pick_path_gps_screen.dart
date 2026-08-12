import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/drug.dart';
import '../models/transaction.dart';
import '../services/supabase_service.dart';
import '../services/offline_sync_service.dart';

class PickPathGpsScreen extends StatefulWidget {
  const PickPathGpsScreen({super.key});

  @override
  State<PickPathGpsScreen> createState() => _PickPathGpsScreenState();
}

class _PickPathGpsScreenState extends State<PickPathGpsScreen> {
  final PageController _pageController = PageController();
  final SupabaseService _supabaseService = SupabaseService();
  final OfflineSyncService _offlineSync = OfflineSyncService();

  List<Drug> _pickingList = [];
  bool _isLoading = true;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadPickItems();
  }

  Future<void> _loadPickItems() async {
    setState(() => _isLoading = true);
    final drugs = await _supabaseService.fetchDrugs();
    if (mounted) {
      setState(() {
        _pickingList = drugs;
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmPickAndNext() async {
    if (_currentIndex >= _pickingList.length) return;

    final currentDrug = _pickingList[_currentIndex];

    // Create pick transaction record
    final tx = TransactionRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      branchId: 'b1',
      drugId: currentDrug.id,
      transactionType: 'sale',
      quantity: 2,
      unitPrice: currentDrug.unitPrice,
      totalAmount: currentDrug.unitPrice * 2,
      transactionDate: DateTime.now(),
      drugName: currentDrug.name,
    );

    // Queue transaction (handles offline/online automatically)
    await _offlineSync.queueTransaction(tx);

    if (_currentIndex < _pickingList.length - 1) {
      setState(() => _currentIndex++);
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _showCompletionDialog();
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(
          'Pick-Path Complete! 🎉',
          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'All ${_pickingList.length} items collected along the optimal GPS aisle route.',
          style: GoogleFonts.inter(color: Colors.white70),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.emerald),
            onPressed: () {
              Navigator.pop(context);
              setState(() => _currentIndex = 0);
              _pageController.jumpToPage(0);
            },
            child: Text('Start New Route', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
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
            const Icon(Icons.navigation_rounded, color: Colors.amberAccent),
            const SizedBox(width: 10),
            Text(
              'Pick-Path GPS (Focus View)',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
        actions: [
          // Offline/Online Status Badge
          ListenableBuilder(
            listenable: _offlineSync,
            builder: (context, _) {
              bool online = _offlineSync.isOnline;
              int pending = _offlineSync.pendingCount;

              return Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: online ? Colors.emerald.withOpacity(0.15) : Colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: online ? Colors.emerald : Colors.amber),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 4,
                      backgroundColor: online ? Colors.emerald : Colors.amber,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      online ? (pending > 0 ? 'Syncing ($pending)...' : 'Online Sync Active') : 'Offline Floor Queue ($pending)',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: online ? Colors.emerald : Colors.amber,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amberAccent))
          : Column(
              children: [
                // Top Progress Bar
                Container(
                  padding: const EdgeInsets.all(16),
                  color: const Color(0xFF1E293B),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Item ${_currentIndex + 1} of ${_pickingList.length}',
                            style: GoogleFonts.inter(color: Colors.white70, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            'Optimal Route GPS',
                            style: GoogleFonts.inter(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      LinearProgressIndicator(
                        value: (_currentIndex + 1) / _pickingList.length,
                        backgroundColor: Colors.white12,
                        color: Colors.amberAccent,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                ),

                // Disabled Scroll PageView (One Item at a Time Focus View)
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(), // SCROLLING DISABLED PER BLUEPRINT
                    itemCount: _pickingList.length,
                    itemBuilder: (context, index) {
                      final drug = _pickingList[index];

                      return Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // MASSIVE LOCATION TYPOGRAPHY CARD
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.amber.shade700, Colors.orangeAccent.shade700],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.amber.withOpacity(0.3),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    'TARGET LOCATION',
                                    style: GoogleFonts.inter(
                                      color: Colors.black54,
                                      fontWeight: FontWeight.black,
                                      fontSize: 12,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    drug.binLocation,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 26, // MASSIVE TEXT
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // DRUG DETAILS CARD
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withOpacity(0.08)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        drug.sku,
                                        style: GoogleFonts.inter(color: Colors.cyanAccent, fontWeight: FontWeight.bold),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(6)),
                                        child: Text(
                                          drug.category,
                                          style: GoogleFonts.inter(color: Colors.white70, fontSize: 11),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    drug.name,
                                    style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                  ),
                                  if (drug.genericName != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Active Ingredient: ${drug.genericName}',
                                      style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
                                    ),
                                  ],
                                  const SizedBox(height: 20),
                                  const Divider(color: Colors.white10),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Quantity to Pick:',
                                        style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
                                      ),
                                      Text(
                                        '2 ${drug.unit}',
                                        style: GoogleFonts.inter(color: Colors.amberAccent, fontSize: 22, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Bottom Fixed Action Button
                Container(
                  padding: const EdgeInsets.all(24),
                  color: const Color(0xFF1E293B),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _confirmPickAndNext,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amberAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.check_circle_rounded, size: 24),
                      label: Text(
                        _currentIndex == _pickingList.length - 1 ? 'Confirm Final Pick & Finish' : 'Confirm Pick & Next Location',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

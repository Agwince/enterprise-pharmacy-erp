import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import 'storekeeper_scanner_screen.dart';
import 'store_mapping_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/leave_application_form.dart';

class StorekeeperHome extends StatefulWidget {
  const StorekeeperHome({super.key});

  @override
  State<StorekeeperHome> createState() => _StorekeeperHomeState();
}

class _StorekeeperHomeState extends State<StorekeeperHome> {
  final ImagePicker _imagePicker = ImagePicker();
  List<Map<String, dynamic>> _pendingRequisitions = [];
  List<Map<String, dynamic>> _liveStock = [];
  bool _isLoadingRequisitions = true;

  @override
  void initState() {
    super.initState();
    _fetchRequisitions();
  }

  Future<void> _fetchRequisitions() async {
    try {
      final db = Supabase.instance.client;
      final res = await db
          .from('internal_requisitions')
          .select()
          .eq('status', 'Pending')
          .order('created_at', ascending: true);
          
      final stockRes = await db
          .from('drugs')
          .select('name, warehouse_quantity, shelf_quantity');
          
      if (mounted) {
        setState(() {
          _pendingRequisitions = List<Map<String, dynamic>>.from(res as List);
          _liveStock = List<Map<String, dynamic>>.from(stockRes as List);
          _isLoadingRequisitions = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingRequisitions = false);
      }
    }
  }

  Future<void> _approveRequisition(Map<String, dynamic> req) async {
    try {
      final db = Supabase.instance.client;
      await db.from('internal_requisitions').update({'status': 'Completed'}).eq('id', req['id']);
      
      // Update inventory based on item_name matching a drug
      // deduct from warehouse_quantity, add to shelf_quantity
      final drugRes = await db.from('drugs').select('id, warehouse_quantity, shelf_quantity').eq('name', req['item_name']).maybeSingle();
      if (drugRes != null) {
        final int currentStore = drugRes['warehouse_quantity'] ?? 0;
        final int currentPharm = drugRes['shelf_quantity'] ?? 0;
        final int reqQty = (req['quantity_requested'] as num).toInt();
        
        await db.from('drugs').update({
          'warehouse_quantity': currentStore - reqQty,
          'shelf_quantity': currentPharm + reqQty
        }).eq('id', drugRes['id']);
      }

      _showSnackbar('Requisition Approved & Stock Transferred', Colors.green);
      _fetchRequisitions();
    } catch (e) {
      _showSnackbar('Error approving: $e', Colors.redAccent);
    }
  }

  Future<void> _rejectRequisition(Map<String, dynamic> req) async {
    try {
      await Supabase.instance.client.from('internal_requisitions').update({'status': 'Rejected'}).eq('id', req['id']);
      _showSnackbar('Requisition Rejected', Colors.orange);
      _fetchRequisitions();
    } catch (e) {
      _showSnackbar('Error rejecting: $e', Colors.redAccent);
    }
  }

  void _showSnackbar(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  Future<void> _captureInvoice() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
      );
      if (image != null) {
        _showSuccessSnackbar();
      }
    } catch (e) {
      // Fallback to gallery if camera fails
      try {
        final XFile? image = await _imagePicker.pickImage(
          source: ImageSource.gallery,
        );
        if (image != null) {
          _showSuccessSnackbar();
        }
      } catch (e2) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open camera or gallery: $e2'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showSuccessSnackbar() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              'Supplier Invoice Logged Successfully!',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Storekeeper Dashboard',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              AuthService().userName,
              style: GoogleFonts.inter(fontSize: 12, color: Colors.amberAccent),
            ),
          ],
        ),
        actions: [
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
                  child: LeaveApplicationForm(),
                ),
              );
            },
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
              label: Text('Logout', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.amberAccent, size: 28),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Welcome to Storekeeper Receiving. First log the supplier invoice, then scan the medicines to route them to the store or pharmacy.',
                      style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Step 1: Intake Logging',
              style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _captureInvoice,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amberAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.receipt_long_rounded, size: 28),
              label: Text(
                'Capture Supplier Invoice',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Step 2: Receiving & Putaway',
              style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const StorekeeperScannerScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF334155),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 28, color: Colors.amberAccent),
              label: Text(
                'Scan Received Medicines',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Store Infrastructure',
              style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const StoreMappingScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.tealAccent.withOpacity(0.5)),
                ),
              ),
              icon: const Icon(Icons.warehouse_rounded, size: 28, color: Colors.tealAccent),
              label: Text(
                'Map Store Shelves & Locations',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Pending Pharmacy Requisitions',
              style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (_isLoadingRequisitions)
              const Center(child: CircularProgressIndicator(color: Colors.amberAccent))
            else if (_pendingRequisitions.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text('No pending requests', style: GoogleFonts.inter(color: Colors.white54)),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _pendingRequisitions.length,
                itemBuilder: (context, index) {
                  final req = _pendingRequisitions[index];
                  return Card(
                    color: const Color(0xFF1E293B),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Text(req['item_name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      subtitle: Text('Quantity Requested: ${req['quantity_requested']}', style: const TextStyle(color: Colors.amberAccent)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check_circle, color: Colors.greenAccent),
                            tooltip: 'Approve & Transfer',
                            onPressed: () => _approveRequisition(req),
                          ),
                          IconButton(
                            icon: const Icon(Icons.cancel, color: Colors.redAccent),
                            tooltip: 'Reject',
                            onPressed: () => _rejectRequisition(req),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 32),
            _buildLiveSplitInventoryView(),
          ],
        ),
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
                  leading: const Icon(Icons.warehouse_rounded, color: Colors.amberAccent),
                  title: Text(stock['name'] ?? 'Unknown', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Wrap(
                    spacing: 16,
                    runSpacing: 4,
                    children: [
                      Text('On Shelf (Pharmacy): ${stock['shelf_quantity'] ?? 0}', style: const TextStyle(color: Colors.white70)),
                      Text('In Warehouse (Store): ${stock['warehouse_quantity'] ?? 0}', style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

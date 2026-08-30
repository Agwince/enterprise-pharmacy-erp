import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/purchase_order.dart';
import '../services/procurement_service.dart';

class ProcurementLpoScreen extends StatefulWidget {
  const ProcurementLpoScreen({super.key});

  @override
  State<ProcurementLpoScreen> createState() => _ProcurementLpoScreenState();
}

class _ProcurementLpoScreenState extends State<ProcurementLpoScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ProcurementService _procurementService;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _procurementService = ProcurementService();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _procurementService,
      child: Consumer<ProcurementService>(
        builder: (context, proc, _) {
          final width = MediaQuery.of(context).size.width;
          final isDesktop = width >= 900;

          return Scaffold(
            backgroundColor: const Color(0xFF050B18),
            appBar: AppBar(
              backgroundColor: const Color(0xFF0A1128),
              elevation: 0,
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.local_shipping_rounded, color: Colors.blueAccent, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Supplier & LPO Procurement Hub',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: isDesktop ? 16 : 14,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Genuine Cost Capture • 3-Way Invoice Matching • Real GL Posting',
                          style: GoogleFonts.inter(color: Colors.white54, fontSize: 10),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                // Branch Switcher
                Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF132043),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: proc.selectedBranchName,
                          dropdownColor: const Color(0xFF132043),
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                          icon: const Icon(Icons.arrow_drop_down, color: Colors.blueAccent, size: 20),
                          items: proc.branches.map((b) {
                            return DropdownMenuItem<String>(
                              value: b['name'],
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.storefront_rounded, size: 14, color: Colors.blueAccent),
                                  const SizedBox(width: 6),
                                  Text(b['name']!),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              proc.setSelectedBranch(val);
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              bottom: TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: Colors.blueAccent,
                labelColor: Colors.blueAccent,
                unselectedLabelColor: Colors.white54,
                labelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
                tabs: const [
                  Tab(text: 'Suppliers Directory'),
                  Tab(text: 'Purchase Orders (LPO)'),
                  Tab(text: 'Goods Received (GRN)'),
                  Tab(text: '3-Way Invoice Match'),
                  Tab(text: 'ABC & Smart Reorder'),
                ],
              ),
            ),
            body: proc.schemaMissing
                ? _buildSchemaNotice()
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildSuppliersTab(isDesktop, proc),
                      _buildPurchaseOrdersTab(isDesktop, proc),
                      _buildGrnTab(isDesktop, proc),
                      _buildThreeWayMatchTab(isDesktop, proc),
                      _buildAbcReorderTab(isDesktop, proc),
                    ],
                  ),
          );
        },
      ),
    );
  }

  Widget _buildSchemaNotice() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.4)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.storage_rounded, color: Colors.blueAccent, size: 24),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Procurement & Suppliers Schema Pending Migration',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'The database tables for suppliers, purchase_orders, purchase_order_items, and inventory_batches are pending execution in your Supabase SQL Editor.',
                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Text(
                    'Run supabase/migrations/20260829_mediocare_finance_hr.sql in your Supabase SQL Editor.',
                    style: GoogleFonts.firaCode(color: Colors.white60, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 1: SUPPLIERS DIRECTORY
  // ===========================================================================
  Widget _buildSuppliersTab(bool isDesktop, ProcurementService proc) {
    final suppliers = proc.suppliers;

    return Padding(
      padding: EdgeInsets.all(isDesktop ? 20.0 : 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Approved Pharma Suppliers (${suppliers.length})',
                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ElevatedButton.icon(
                onPressed: () => _showSupplierModal(null),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                icon: const Icon(Icons.person_add_rounded, size: 16),
                label: Text('New Supplier', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: suppliers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.business_rounded, color: Colors.white24, size: 48),
                          const SizedBox(height: 10),
                          Text('No suppliers registered in database.', style: GoogleFonts.inter(color: Colors.white54, fontSize: 14)),
                          const SizedBox(height: 4),
                          Text('Tap "New Supplier" to add verified pharmaceutical distributors.', style: GoogleFonts.inter(color: Colors.white38, fontSize: 11)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: suppliers.length,
                      separatorBuilder: (_, _) => Divider(color: Colors.white.withValues(alpha: 0.05), height: 1),
                      itemBuilder: (context, idx) {
                        final s = suppliers[idx];

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blueAccent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.business_center_rounded, color: Colors.blueAccent, size: 20),
                          ),
                          title: Text(s.name, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 14,
                                children: [
                                  if (s.code != null) Text('Code: ${s.code}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                  if (s.kraPin != null) Text('KRA PIN: ${s.kraPin}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                  if (s.phone != null) Text('Phone: ${s.phone}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                  if (s.paymentTerms != null) Text('Terms: ${s.paymentTerms}', style: const TextStyle(color: Colors.tealAccent, fontSize: 11)),
                                  if (s.leadTimeDays != null) Text('Lead Time: ${s.leadTimeDays} days', style: const TextStyle(color: Colors.amberAccent, fontSize: 11)),
                                ],
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (s.creditLimit != null)
                                Text(
                                  'Limit: KES ${NumberFormat("#,##0").format(s.creditLimit)}',
                                  style: GoogleFonts.inter(color: Colors.white54, fontSize: 11),
                                ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.edit_note_rounded, color: Colors.white70),
                                tooltip: 'Edit Supplier',
                                onPressed: () => _showSupplierModal(s),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSupplierModal(Supplier? existing) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final codeCtrl = TextEditingController(text: existing?.code ?? '');
    final pinCtrl = TextEditingController(text: existing?.kraPin ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final emailCtrl = TextEditingController(text: existing?.email ?? '');
    final contactCtrl = TextEditingController(text: existing?.contactPerson ?? '');
    final termsCtrl = TextEditingController(text: existing?.paymentTerms ?? '');
    final limitCtrl = TextEditingController(text: existing?.creditLimit?.toString() ?? '');
    final leadCtrl = TextEditingController(text: existing?.leadTimeDays?.toString() ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          existing == null ? 'Register New Supplier' : 'Edit Supplier',
          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(labelText: 'Supplier / Distributor Name *', labelStyle: TextStyle(color: Colors.white54)),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: codeCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: const InputDecoration(labelText: 'Supplier Code', labelStyle: TextStyle(color: Colors.white54)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: pinCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: const InputDecoration(labelText: 'KRA PIN', labelStyle: TextStyle(color: Colors.white54)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: phoneCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: const InputDecoration(labelText: 'Phone', labelStyle: TextStyle(color: Colors.white54)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: emailCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: const InputDecoration(labelText: 'Email', labelStyle: TextStyle(color: Colors.white54)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: contactCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(labelText: 'Contact Person / Key Account Manager', labelStyle: TextStyle(color: Colors.white54)),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: termsCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: const InputDecoration(labelText: 'Payment Terms (e.g. 30 Days)', labelStyle: TextStyle(color: Colors.white54)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: leadCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: const InputDecoration(labelText: 'Lead Time (Days)', labelStyle: TextStyle(color: Colors.white54)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: limitCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(labelText: 'Credit Limit (KES)', labelStyle: TextStyle(color: Colors.white54)),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isNotEmpty) {
                await _procurementService.saveSupplier(
                  id: existing?.id,
                  name: nameCtrl.text.trim(),
                  code: codeCtrl.text.trim(),
                  kraPin: pinCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                  email: emailCtrl.text.trim(),
                  contactPerson: contactCtrl.text.trim(),
                  paymentTerms: termsCtrl.text.trim(),
                  creditLimit: double.tryParse(limitCtrl.text),
                  leadTimeDays: int.tryParse(leadCtrl.text),
                );
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
            child: const Text('Save Supplier'),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 2: PURCHASE ORDERS (LPO)
  // ===========================================================================
  Widget _buildPurchaseOrdersTab(bool isDesktop, ProcurementService proc) {
    final pos = proc.purchaseOrders;

    return Padding(
      padding: EdgeInsets.all(isDesktop ? 20.0 : 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Local Purchase Orders (${pos.length})',
                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ElevatedButton.icon(
                onPressed: () => _showCreateLpoModal(proc),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                icon: const Icon(Icons.note_add_rounded, size: 16),
                label: Text('Create LPO', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: pos.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.request_quote_rounded, color: Colors.white24, size: 48),
                          const SizedBox(height: 10),
                          Text('No purchase orders recorded in database.', style: GoogleFonts.inter(color: Colors.white54, fontSize: 14)),
                          const SizedBox(height: 4),
                          Text('Create a new LPO or generate draft LPOs via Smart ABC Reorder.', style: GoogleFonts.inter(color: Colors.white38, fontSize: 11)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: pos.length,
                      separatorBuilder: (_, _) => Divider(color: Colors.white.withValues(alpha: 0.05), height: 1),
                      itemBuilder: (context, idx) {
                        final po = pos[idx];
                        Color statusColor;
                        if (po.isDraft) {
                          statusColor = Colors.amberAccent;
                        } else if (po.isApproved) {
                          statusColor = Colors.cyanAccent;
                        } else if (po.isSent) {
                          statusColor = Colors.blueAccent;
                        } else if (po.isReceived) {
                          statusColor = const Color(0xFF10B981);
                        } else if (po.isClosed) {
                          statusColor = Colors.purpleAccent;
                        } else {
                          statusColor = Colors.redAccent;
                        }

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.description_rounded, color: statusColor, size: 20),
                          ),
                          title: Row(
                            children: [
                              Text(po.poNumber, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(po.status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Supplier: ${po.supplierName ?? "Unassigned"} • ${po.items.length} Line Items • ${DateFormat("yyyy-MM-dd").format(po.createdAt)}',
                                  style: GoogleFonts.inter(color: Colors.white54, fontSize: 11)),
                              if (po.grnNumber != null)
                                Text('GRN: ${po.grnNumber} • Received Value: KES ${NumberFormat("#,##0.00").format(po.grnTotalCost)}',
                                    style: const TextStyle(color: Color(0xFF10B981), fontSize: 10)),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'KES ${NumberFormat("#,##0.00").format(po.totalAmount)}',
                                style: GoogleFonts.inter(color: Colors.tealAccent, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(width: 8),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert_rounded, color: Colors.white70),
                                color: const Color(0xFF1E293B),
                                itemBuilder: (ctx) => [
                                  if (po.isDraft)
                                    const PopupMenuItem(value: 'approve', child: Text('Approve LPO', style: TextStyle(color: Colors.white))),
                                  if (po.isApproved)
                                    const PopupMenuItem(value: 'send', child: Text('Mark as Sent to Supplier', style: TextStyle(color: Colors.white))),
                                  const PopupMenuItem(value: 'view', child: Text('View / Print LPO Slip', style: TextStyle(color: Colors.white))),
                                ],
                                onSelected: (val) async {
                                  if (val == 'approve') {
                                    await proc.updatePOStatus(po.id, 'approved', approvedBy: 'Superintendent Pharmacist');
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ LPO Approved and ready for transmission!')));
                                    }
                                  } else if (val == 'send') {
                                    await proc.updatePOStatus(po.id, 'send');
                                  } else if (val == 'view') {
                                    _showLpoPrintDialog(po);
                                  }
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateLpoModal(ProcurementService proc) {
    String? selectedSupplierId = proc.suppliers.isNotEmpty ? proc.suppliers.first.id : null;
    final notesCtrl = TextEditingController();
    final List<Map<String, dynamic>> draftItems = [];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final totalBudget = draftItems.fold(0.0, (sum, i) => sum + (((i['quantity_requested'] as num?)?.toInt() ?? 0) * ((i['unit_cost'] as num?)?.toDouble() ?? 0.0)));

          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: Text('Create Local Purchase Order (LPO)', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 540,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (proc.suppliers.isNotEmpty)
                      DropdownButtonFormField<String>(
                        key: ValueKey(selectedSupplierId),
                        initialValue: selectedSupplierId,
                        dropdownColor: const Color(0xFF1E293B),
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: const InputDecoration(labelText: 'Supplier', labelStyle: TextStyle(color: Colors.white54)),
                        items: proc.suppliers.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                        onChanged: (v) => setModalState(() => selectedSupplierId = v),
                      )
                    else
                      const Text('⚠️ No suppliers registered. Add suppliers in the Suppliers tab first.', style: TextStyle(color: Colors.amberAccent, fontSize: 12)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: notesCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(labelText: 'Order Notes / Delivery Terms', labelStyle: TextStyle(color: Colors.white54)),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Line Items (${draftItems.length})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        TextButton.icon(
                          onPressed: () {
                            if (proc.drugs.isNotEmpty) {
                              final d = proc.drugs.first;
                              setModalState(() {
                                draftItems.add({
                                  'drug_id': d.id,
                                  'drug_name': d.name,
                                  'drug_sku': d.sku,
                                  'quantity_requested': 10,
                                  'unit_cost': d.costPrice > 0.0 ? d.costPrice : d.unitPrice,
                                });
                              });
                            }
                          },
                          icon: const Icon(Icons.add_circle_outline, size: 14, color: Colors.blueAccent),
                          label: const Text('Add Drug', style: TextStyle(color: Colors.blueAccent, fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ...draftItems.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final item = entry.value;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(item['drug_name']?.toString() ?? 'Drug', style: const TextStyle(color: Colors.white, fontSize: 12), overflow: TextOverflow.ellipsis),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 60,
                              child: TextFormField(
                                initialValue: item['quantity_requested']?.toString(),
                                keyboardType: TextInputType.number,
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                                decoration: const InputDecoration(labelText: 'Qty', labelStyle: TextStyle(color: Colors.white54, fontSize: 10)),
                                onChanged: (v) => item['quantity_requested'] = int.tryParse(v) ?? 1,
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 80,
                              child: TextFormField(
                                initialValue: item['unit_cost']?.toString(),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                                decoration: const InputDecoration(labelText: 'Unit Cost', labelStyle: TextStyle(color: Colors.white54, fontSize: 10)),
                                onChanged: (v) => item['unit_cost'] = double.tryParse(v) ?? 0.0,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.redAccent, size: 16),
                              onPressed: () => setModalState(() => draftItems.removeAt(idx)),
                            ),
                          ],
                        ),
                      );
                    }),
                    const Divider(color: Colors.white24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('TOTAL BUDGETED LPO VALUE:', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                        Text('KES ${NumberFormat("#,##0.00").format(totalBudget)}', style: const TextStyle(color: Colors.tealAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
              ElevatedButton(
                onPressed: draftItems.isEmpty
                    ? null
                    : () async {
                        final sup = proc.suppliers.firstWhere((s) => s.id == selectedSupplierId, orElse: () => proc.suppliers.first);
                        await proc.createPurchaseOrder(
                          branchId: proc.selectedBranchId,
                          branchName: proc.selectedBranchName,
                          supplierId: selectedSupplierId,
                          supplierName: sup.name,
                          notes: notesCtrl.text.trim(),
                          lineItems: draftItems,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                child: const Text('Generate LPO'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showLpoPrintDialog(PurchaseOrder po) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 420,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text('MEDIOCARE PHARMACY GROUP', style: GoogleFonts.courierPrime(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black)),
                Text('LOCAL PURCHASE ORDER (LPO)', style: GoogleFonts.courierPrime(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
                Text('LPO NO: ${po.poNumber}', style: GoogleFonts.courierPrime(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black)),
                Text('DATE: ${DateFormat("yyyy-MM-dd").format(po.createdAt)}', style: GoogleFonts.courierPrime(fontSize: 10, color: Colors.black87)),
                Text('DESTINATION: ${po.branchName ?? "HQ"}', style: GoogleFonts.courierPrime(fontSize: 10, color: Colors.black87)),
                Text('SUPPLIER: ${po.supplierName ?? "Pharma Distributor"}', style: GoogleFonts.courierPrime(fontSize: 10, color: Colors.black87)),
                const Divider(color: Colors.black54),
                Column(
                  children: po.items.map((i) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text('${i.quantityRequested}x ${i.drugName ?? "Item"}', style: GoogleFonts.courierPrime(fontSize: 10, color: Colors.black))),
                          Text('KES ${NumberFormat("#,##0.00").format(i.requestedTotal)}', style: GoogleFonts.courierPrime(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const Divider(color: Colors.black54),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('TOTAL LPO AMOUNT:', style: GoogleFonts.courierPrime(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black)),
                    Text('KES ${NumberFormat("#,##0.00").format(po.totalAmount)}', style: GoogleFonts.courierPrime(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black)),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Authorised By: ${po.approvedBy ?? "Procurement Directorate"}', style: GoogleFonts.courierPrime(fontSize: 9, fontStyle: FontStyle.italic, color: Colors.black87)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 3: GOODS RECEIVED NOTE (GRN) & GENUINE COST CAPTURE
  // ===========================================================================
  Widget _buildGrnTab(bool isDesktop, ProcurementService proc) {
    final pendingOrders = proc.purchaseOrders.where((p) => p.isApproved || p.isSent).toList();
    final receivedOrders = proc.purchaseOrders.where((p) => p.isReceived || p.isClosed).toList();

    return Padding(
      padding: EdgeInsets.all(isDesktop ? 20.0 : 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Goods Receiving & Real Cost Capture', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('Auto GL Dr Inventory (1300) / Cr Payables (2000)', style: GoogleFonts.inter(color: const Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pending LPOs Awaiting Physical Receipt (${pendingOrders.length})', style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  if (pendingOrders.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(10)),
                      child: const Center(child: Text('No approved LPOs waiting for delivery.', style: TextStyle(color: Colors.white54, fontSize: 12))),
                    )
                  else
                    ...pendingOrders.map((po) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${po.poNumber} ➔ ${po.supplierName ?? "Supplier"}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                Text('${po.items.length} Items • Budgeted Value: KES ${NumberFormat("#,##0.00").format(po.totalAmount)}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                              ],
                            ),
                            ElevatedButton.icon(
                              onPressed: () => _showReceiveGrnModal(po, proc),
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.black),
                              icon: const Icon(Icons.inventory_rounded, size: 16),
                              label: const Text('Process GRN Receipt', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                            ),
                          ],
                        ),
                      );
                    }),
                  const SizedBox(height: 20),
                  const Text('Completed Goods Received Notes (GRN Audit History)', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  if (receivedOrders.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(10)),
                      child: const Center(child: Text('No received goods notes recorded yet.', style: TextStyle(color: Colors.white54, fontSize: 12))),
                    )
                  else
                    ...receivedOrders.map((po) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${po.grnNumber ?? "GRN"} • PO: ${po.poNumber}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                Text('Received By: ${po.receivedBy ?? "Storekeeper"} • Date: ${po.grnDate != null ? DateFormat("yyyy-MM-dd HH:mm").format(po.grnDate!) : "N/A"}',
                                    style: const TextStyle(color: Colors.white54, fontSize: 10)),
                              ],
                            ),
                            Text('Real Value: KES ${NumberFormat("#,##0.00").format(po.grnTotalCost)}',
                                style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showReceiveGrnModal(PurchaseOrder po, ProcurementService proc) {
    final receiverCtrl = TextEditingController(text: 'Storekeeper John');
    final List<Map<String, dynamic>> receivingItems = po.items.map((i) {
      return {
        'id': i.id,
        'drug_id': i.drugId,
        'drug_name': i.drugName,
        'quantity_requested': i.quantityRequested,
        'quantity_received': i.quantityRequested,
        'real_grn_cost': i.unitCost, // Genuine cost price entered at receipt
        'batch_no': 'LOT-${DateFormat("yyyyMM").format(DateTime.now())}',
        'expiry_date': DateTime.now().add(const Duration(days: 540)).toIso8601String().substring(0, 10),
      };
    }).toList();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: Text('Process Goods Received Note (GRN) — ${po.poNumber}',
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 580,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: receiverCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(labelText: 'Receiving Pharmacist / Storekeeper', labelStyle: TextStyle(color: Colors.white54)),
                    ),
                    const SizedBox(height: 12),
                    const Text('Capture Real Received Physical Quantities & Verified Cost Prices:',
                        style: TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 8),
                    ...receivingItems.map((item) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(8)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item['drug_name']?.toString() ?? 'Drug', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    initialValue: item['quantity_received']?.toString(),
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(color: Colors.white, fontSize: 12),
                                    decoration: const InputDecoration(labelText: 'Received Qty', labelStyle: TextStyle(color: Colors.white54, fontSize: 10)),
                                    onChanged: (v) => item['quantity_received'] = int.tryParse(v) ?? 0,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    initialValue: item['real_grn_cost']?.toString(),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    style: const TextStyle(color: Colors.tealAccent, fontSize: 12, fontWeight: FontWeight.bold),
                                    decoration: const InputDecoration(labelText: 'Real Cost Price (KES) *', labelStyle: TextStyle(color: Colors.tealAccent, fontSize: 10)),
                                    onChanged: (v) => item['real_grn_cost'] = double.tryParse(v) ?? 0.0,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    initialValue: item['batch_no']?.toString(),
                                    style: const TextStyle(color: Colors.white, fontSize: 12),
                                    decoration: const InputDecoration(labelText: 'Batch Lot #', labelStyle: TextStyle(color: Colors.white54, fontSize: 10)),
                                    onChanged: (v) => item['batch_no'] = v,
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
                onPressed: () async {
                  final result = await proc.receiveGRN(
                    poId: po.id,
                    receivedBy: receiverCtrl.text.trim().isEmpty ? 'Storekeeper' : receiverCtrl.text.trim(),
                    receivedItems: receivingItems,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: const Color(0xFF10B981),
                      content: Text('✅ ${result['grn_number']} processed! ${result['message']}'),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.black),
                child: const Text('Confirm Receipt & Post to GL'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ===========================================================================
  // TAB 4: THREE-WAY INVOICE MATCHING
  // ===========================================================================
  Widget _buildThreeWayMatchTab(bool isDesktop, ProcurementService proc) {
    final allPos = proc.purchaseOrders;

    return Padding(
      padding: EdgeInsets.all(isDesktop ? 20.0 : 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('3-Way Matching (LPO vs GRN vs Supplier Invoice)',
                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.purpleAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('Tolerance: ± KES 500 / 5%', style: GoogleFonts.inter(color: Colors.purpleAccent, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: allPos.isEmpty
                  ? Center(child: Text('No purchase orders to match.', style: GoogleFonts.inter(color: Colors.white54)))
                  : ListView.separated(
                      itemCount: allPos.length,
                      separatorBuilder: (_, _) => Divider(color: Colors.white.withValues(alpha: 0.05), height: 1),
                      itemBuilder: (context, idx) {
                        final po = allPos[idx];
                        Color matchColor;
                        String matchLabel = po.matchStatus;
                        if (po.matchStatus == 'MATCHED') {
                          matchColor = const Color(0xFF10B981);
                        } else if (po.matchStatus == 'QTY_VARIANCE') {
                          matchColor = Colors.amberAccent;
                        } else if (po.matchStatus == 'PRICE_VARIANCE') {
                          matchColor = Colors.orangeAccent;
                        } else if (po.matchStatus == 'BLOCKED') {
                          matchColor = Colors.redAccent;
                        } else {
                          matchColor = Colors.white38;
                          matchLabel = 'UNMATCHED';
                        }

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: matchColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.rule_folder_rounded, color: matchColor, size: 22),
                          ),
                          title: Row(
                            children: [
                              Text(po.poNumber, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: matchColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(matchLabel, style: TextStyle(color: matchColor, fontSize: 9, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('LPO Budget: KES ${NumberFormat("#,##0").format(po.totalAmount)} • GRN Value: KES ${NumberFormat("#,##0").format(po.grnTotalCost)}',
                                  style: const TextStyle(color: Colors.white54, fontSize: 11)),
                              if (po.invoiceNumber != null)
                                Text('Invoice: ${po.invoiceNumber} (KES ${NumberFormat("#,##0").format(po.invoiceAmount ?? 0.0)})',
                                    style: const TextStyle(color: Colors.tealAccent, fontSize: 10)),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ElevatedButton(
                                onPressed: () => _showMatchInvoiceDialog(po, proc),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E293B),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                child: const Text('Match Invoice', style: TextStyle(fontSize: 11)),
                              ),
                              if (po.matchStatus == 'MATCHED' && !po.isClosed) ...[
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () async {
                                    final res = await proc.paySupplierInvoice(poId: po.id, paymentAmount: po.invoiceAmount ?? po.grnTotalCost);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(backgroundColor: const Color(0xFF10B981), content: Text('✅ ${res['message']}')),
                                      );
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981),
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  ),
                                  child: const Text('Pay & Settle GL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMatchInvoiceDialog(PurchaseOrder po, ProcurementService proc) {
    final invNumCtrl = TextEditingController(text: po.invoiceNumber ?? 'INV-${DateFormat("yyyyMMdd").format(DateTime.now())}');
    final invAmtCtrl = TextEditingController(text: (po.invoiceAmount ?? (po.grnTotalCost > 0 ? po.grnTotalCost : po.totalAmount)).toStringAsFixed(2));
    final tolCtrl = TextEditingController(text: po.matchTolerance.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('3-Way Match: ${po.poNumber}', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('1. LPO Ordered Total: KES ${NumberFormat("#,##0.00").format(po.totalAmount)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                Text('2. GRN Physical Total: KES ${NumberFormat("#,##0.00").format(po.grnTotalCost)}', style: const TextStyle(color: Colors.tealAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                const Divider(color: Colors.white24),
                const Text('3. Enter Supplier Invoice Details:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 8),
                TextField(
                  controller: invNumCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(labelText: 'Supplier Invoice Number', labelStyle: TextStyle(color: Colors.white54)),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: invAmtCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(labelText: 'Billed Invoice Amount (KES)', labelStyle: TextStyle(color: Colors.white54)),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: tolCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(labelText: 'Tolerance Threshold (KES)', labelStyle: TextStyle(color: Colors.white54)),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () async {
              final amt = double.tryParse(invAmtCtrl.text) ?? 0.0;
              final tol = double.tryParse(tolCtrl.text) ?? 500.0;
              final status = await proc.matchSupplierInvoice(
                poId: po.id,
                invoiceNumber: invNumCtrl.text.trim(),
                invoiceAmount: amt,
                tolerance: tol,
              );
              if (ctx.mounted) Navigator.pop(ctx);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('3-Way Match Result: $status')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent, foregroundColor: Colors.white),
            child: const Text('Run 3-Way Match'),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 5: ABC VELOCITY & SMART REORDER
  // ===========================================================================
  Widget _buildAbcReorderTab(bool isDesktop, ProcurementService proc) {
    final abcList = proc.abcItems;

    return Padding(
      padding: EdgeInsets.all(isDesktop ? 20.0 : 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Smart Replenishment & ABC Velocity Analysis', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ElevatedButton.icon(
                onPressed: () async {
                  final res = await proc.autoDraftFromReplenishment();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: const Color(0xFF10B981),
                      content: Text(res['message']?.toString() ?? 'Auto-draft PO complete!'),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.black),
                icon: const Icon(Icons.auto_awesome, size: 16),
                label: Text('Auto-Draft PO from ABC', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: abcList.isEmpty
                  ? Center(child: Text('No ABC items analyzed for this branch.', style: GoogleFonts.inter(color: Colors.white54)))
                  : ListView.separated(
                      itemCount: abcList.length,
                      separatorBuilder: (_, _) => Divider(color: Colors.white.withValues(alpha: 0.05), height: 1),
                      itemBuilder: (context, idx) {
                        final item = abcList[idx];
                        final abcClass = item['abc_class']?.toString() ?? 'B';
                        Color classColor;
                        if (abcClass == 'Fast' || abcClass == 'A') {
                          classColor = Colors.tealAccent;
                        } else if (abcClass == 'Slow' || abcClass == 'B') {
                          classColor = Colors.amberAccent;
                        } else {
                          classColor = Colors.redAccent;
                        }

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: classColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                            child: Icon(Icons.trending_up_rounded, color: classColor, size: 20),
                          ),
                          title: Text(item['name']?.toString() ?? 'Drug', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: Text('Class: $abcClass • Stock: ${item['current_stock'] ?? 0} • Velocity (30d): ${item['units_sold_30d'] ?? 0} units',
                              style: const TextStyle(color: Colors.white54, fontSize: 11)),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: classColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                            child: Text(abcClass.toUpperCase(), style: TextStyle(color: classColor, fontWeight: FontWeight.bold, fontSize: 11)),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

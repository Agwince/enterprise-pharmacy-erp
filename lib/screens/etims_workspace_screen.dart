import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:provider/provider.dart';
import '../models/etims_invoice.dart';
import '../services/etims_service.dart';

class ETIMSWorkspaceScreen extends StatefulWidget {
  const ETIMSWorkspaceScreen({super.key});

  @override
  State<ETIMSWorkspaceScreen> createState() => _ETIMSWorkspaceScreenState();
}

class _ETIMSWorkspaceScreenState extends State<ETIMSWorkspaceScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ETIMSService _etimsService;

  // New Invoice State
  final _customerNameCtrl = TextEditingController();
  final _customerPinCtrl = TextEditingController();
  final _paymentRefCtrl = TextEditingController();
  final _cashierCtrl = TextEditingController();
  String _selectedPaymentMode = 'M-Pesa';

  // Active Draft Items in Terminal (Populated when drugs are selected or scanned)
  final List<ETIMSLineItem> _draftItems = [];

  // Till Reconciliation Form State
  final _floatCtrl = TextEditingController();
  final _cashSalesCtrl = TextEditingController();
  final _mpesaSalesCtrl = TextEditingController();
  final _cardSalesCtrl = TextEditingController();
  final _insuranceSalesCtrl = TextEditingController();
  final _pettyCashCtrl = TextEditingController();
  final _actualCashCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  ETIMSInvoice? _lastGeneratedInvoice;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _etimsService = ETIMSService();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _customerNameCtrl.dispose();
    _customerPinCtrl.dispose();
    _paymentRefCtrl.dispose();
    _cashierCtrl.dispose();
    _floatCtrl.dispose();
    _cashSalesCtrl.dispose();
    _mpesaSalesCtrl.dispose();
    _cardSalesCtrl.dispose();
    _insuranceSalesCtrl.dispose();
    _pettyCashCtrl.dispose();
    _actualCashCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _etimsService,
      child: Consumer<ETIMSService>(
        builder: (context, etims, _) {
          final width = MediaQuery.of(context).size.width;
          final isDesktop = width >= 900;
          final cfg = etims.currentBranchConfig;

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
                      color: Colors.tealAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.tealAccent, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'KRA eTIMS / e-Invoicing Compliance',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: isDesktop ? 16 : 14,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          cfg != null
                              ? 'KRA PIN: ${cfg.kraPin} • CU Device: ${cfg.machineNumber}'
                              : 'KRA Device Not Configured for ${etims.selectedBranch}',
                          style: GoogleFonts.inter(
                            color: cfg != null ? Colors.white54 : Colors.amberAccent,
                            fontSize: 10,
                            fontWeight: cfg != null ? FontWeight.normal : FontWeight.bold,
                          ),
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
                        border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.3)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: etims.selectedBranch,
                          dropdownColor: const Color(0xFF132043),
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                          icon: const Icon(Icons.arrow_drop_down, color: Colors.tealAccent, size: 20),
                          items: etims.branches.map((b) {
                            return DropdownMenuItem<String>(
                              value: b['name'],
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.storefront_rounded, size: 14, color: Colors.tealAccent),
                                  const SizedBox(width: 6),
                                  Text(b['name']!),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              etims.setSelectedBranch(val);
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
                indicatorColor: Colors.tealAccent,
                labelColor: Colors.tealAccent,
                unselectedLabelColor: Colors.white54,
                labelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
                tabs: const [
                  Tab(text: 'e-Invoice Terminal'),
                  Tab(text: 'Signed Invoices Register'),
                  Tab(text: 'Daily Z-Report & Tax'),
                  Tab(text: 'Branch Till Reconciliation'),
                ],
              ),
            ),
            body: etims.schemaMissing
                ? _buildSchemaNotice()
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildInvoiceTerminalTab(isDesktop, etims),
                      _buildInvoicesRegisterTab(isDesktop, etims),
                      _buildDailyZReportTab(isDesktop, etims),
                      _buildTillReconciliationTab(isDesktop, etims),
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
          constraints: const BoxConstraints(maxWidth: 640),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.4)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.qr_code_scanner_rounded, color: Colors.tealAccent, size: 24),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'eTIMS Schema & Device Config Pending Migration',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'The KRA eTIMS tables (branch_kra_config, etims_invoices, etims_z_reports, branch_till_sessions) are pending execution in your Supabase SQL Editor.',
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('HOW TO RUN MIGRATION:', style: GoogleFonts.inter(color: Colors.tealAccent, fontWeight: FontWeight.bold, fontSize: 11)),
                      const SizedBox(height: 6),
                      Text(
                        '1. Open Supabase Dashboard ➔ SQL Editor\n'
                        '2. Open supabase/migrations/20260829_mediocare_finance_hr.sql\n'
                        '3. Click RUN to create tables, tax classification DDL & RLS policies.',
                        style: GoogleFonts.firaCode(color: Colors.white60, fontSize: 11, height: 1.4),
                      ),
                    ],
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
  // TAB 1: Live e-Invoice Generator & QR Terminal
  // ===========================================================================
  Widget _buildInvoiceTerminalTab(bool isDesktop, ETIMSService etims) {
    final totalGross = _draftItems.fold(0.0, (sum, i) => sum + i.grossTotal);
    final totalNet = _draftItems.fold(0.0, (sum, i) => sum + i.netAmount);
    final totalTax = _draftItems.fold(0.0, (sum, i) => sum + i.taxAmount);

    final totalA = _draftItems.where((i) => i.taxCode == TIMSTaxCode.A).fold(0.0, (sum, i) => sum + i.grossTotal);
    final totalB = _draftItems.where((i) => i.taxCode == TIMSTaxCode.B).fold(0.0, (sum, i) => sum + i.netAmount);
    final totalTaxB = _draftItems.where((i) => i.taxCode == TIMSTaxCode.B).fold(0.0, (sum, i) => sum + i.taxAmount);
    final totalC = _draftItems.where((i) => i.taxCode == TIMSTaxCode.C).fold(0.0, (sum, i) => sum + i.grossTotal);
    final totalD = _draftItems.where((i) => i.taxCode == TIMSTaxCode.D).fold(0.0, (sum, i) => sum + i.grossTotal);
    final totalE = _draftItems.where((i) => i.taxCode == TIMSTaxCode.E).fold(0.0, (sum, i) => sum + i.netAmount);
    final totalTaxE = _draftItems.where((i) => i.taxCode == TIMSTaxCode.E).fold(0.0, (sum, i) => sum + i.taxAmount);

    final isConfigured = etims.isCurrentBranchConfigured;

    final formPanel = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isConfigured)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amberAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.amberAccent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'KRA Control Unit device not configured for ${etims.selectedBranch}. Enter real device settings in branch_kra_config table.',
                      style: GoogleFonts.inter(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Customer & Fiscal Details', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.tealAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('KRA TIMS v2.1 (A/B/C/D/E)', style: GoogleFonts.inter(color: Colors.tealAccent, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: isDesktop ? 220 : double.infinity,
                child: TextField(
                  controller: _customerNameCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Customer / Facility Name',
                    labelStyle: TextStyle(color: Colors.white54, fontSize: 12),
                    filled: true,
                    fillColor: Color(0xFF1E293B),
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                  ),
                ),
              ),
              SizedBox(
                width: isDesktop ? 180 : double.infinity,
                child: TextField(
                  controller: _customerPinCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Customer KRA PIN (B2B)',
                    hintText: 'e.g. P051122334A',
                    labelStyle: TextStyle(color: Colors.white54, fontSize: 12),
                    hintStyle: TextStyle(color: Colors.white24, fontSize: 12),
                    filled: true,
                    fillColor: Color(0xFF1E293B),
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                  ),
                ),
              ),
              SizedBox(
                width: isDesktop ? 140 : double.infinity,
                child: DropdownButtonFormField<String>(
                  key: ValueKey(_selectedPaymentMode),
                  initialValue: _selectedPaymentMode,
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Payment Mode',
                    labelStyle: TextStyle(color: Colors.white54, fontSize: 12),
                    filled: true,
                    fillColor: Color(0xFF1E293B),
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'M-Pesa', child: Text('M-Pesa')),
                    DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                    DropdownMenuItem(value: 'Card', child: Text('Card')),
                    DropdownMenuItem(value: 'Insurance', child: Text('Insurance')),
                  ],
                  onChanged: (v) => setState(() => _selectedPaymentMode = v ?? 'M-Pesa'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Invoice Line Items (${_draftItems.length})', style: GoogleFonts.inter(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13)),
              TextButton.icon(
                onPressed: _showAddItemModal,
                icon: const Icon(Icons.add_circle_outline_rounded, size: 16, color: Colors.tealAccent),
                label: const Text('Add Item', style: TextStyle(color: Colors.tealAccent, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Items Table
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFF132043)),
              columns: const [
                DataColumn(label: Text('Item / Drug Name', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('KRA Tax Code', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Qty', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Unit Price', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Total (KES)', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Action', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
              ],
              rows: _draftItems.map((item) {
                Color codeColor;
                if (item.taxCode == TIMSTaxCode.B) {
                  codeColor = Colors.tealAccent;
                } else if (item.taxCode == TIMSTaxCode.A) {
                  codeColor = Colors.purpleAccent;
                } else if (item.taxCode == TIMSTaxCode.C) {
                  codeColor = Colors.cyanAccent;
                } else if (item.taxCode == TIMSTaxCode.E) {
                  codeColor = Colors.amberAccent;
                } else {
                  codeColor = Colors.white54;
                }

                return DataRow(
                  cells: [
                    DataCell(Text(item.itemName, style: const TextStyle(color: Colors.white, fontSize: 12))),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: codeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Code ${item.taxCode.code} (${(item.taxRate * 100).toInt()}%)',
                          style: TextStyle(
                            color: codeColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    DataCell(Text('${item.quantity}', style: const TextStyle(color: Colors.white, fontSize: 12))),
                    DataCell(Text(NumberFormat("#,##0.00").format(item.unitPrice), style: const TextStyle(color: Colors.white70, fontSize: 12))),
                    DataCell(Text(NumberFormat("#,##0.00").format(item.grossTotal), style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold, fontSize: 12))),
                    DataCell(
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                        onPressed: () => setState(() => _draftItems.remove(item)),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // Real-time Fiscal Tax Summary Grid
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF132043),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Column(
              children: [
                _buildTaxSummaryRow('Code B Taxable Value (16% Standard VAT):', 'KES ${NumberFormat("#,##0.00").format(totalB)}', Colors.white70),
                _buildTaxSummaryRow('Code B VAT Output (16% - Credit Allowed):', 'KES ${NumberFormat("#,##0.00").format(totalTaxB)}', Colors.tealAccent),
                _buildTaxSummaryRow('Code A Exempt Value (0% - Input Blocked):', 'KES ${NumberFormat("#,##0.00").format(totalA)}', Colors.purpleAccent),
                _buildTaxSummaryRow('Code C Zero-Rated Value (0% - Credit Allowed):', 'KES ${NumberFormat("#,##0.00").format(totalC)}', Colors.cyanAccent),
                if (totalD > 0) _buildTaxSummaryRow('Code D Non-VAT Value (0%):', 'KES ${NumberFormat("#,##0.00").format(totalD)}', Colors.white54),
                if (totalE > 0) _buildTaxSummaryRow('Code E Taxable Value (8% Reduced VAT):', 'KES ${NumberFormat("#,##0.00").format(totalE)}', Colors.amberAccent),
                if (totalTaxE > 0) _buildTaxSummaryRow('Code E VAT Output (8%):', 'KES ${NumberFormat("#,##0.00").format(totalTaxE)}', Colors.amberAccent),
                const Divider(color: Colors.white24),
                _buildTaxSummaryRow('Total Net Sales:', 'KES ${NumberFormat("#,##0.00").format(totalNet)}', Colors.white70),
                _buildTaxSummaryRow('Total Output VAT Collected:', 'KES ${NumberFormat("#,##0.00").format(totalTax)}', Colors.tealAccent),
                _buildTaxSummaryRow('GRAND TOTAL INVOICE VALUE:', 'KES ${NumberFormat("#,##0.00").format(totalGross)}', Colors.tealAccent, isBold: true),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Sign & Pre-Validate Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _draftItems.isEmpty
                  ? null
                  : () async {
                      final inv = await etims.generateInvoice(
                        items: List.from(_draftItems),
                        branchName: etims.selectedBranch,
                        branchId: etims.selectedBranchId,
                        customerName: _customerNameCtrl.text.trim().isEmpty ? 'Walk-in Customer' : _customerNameCtrl.text.trim(),
                        customerPin: _customerPinCtrl.text.trim(),
                        paymentMode: _selectedPaymentMode,
                        paymentReference: _paymentRefCtrl.text.trim(),
                        cashierName: _cashierCtrl.text.trim(),
                      );
                      setState(() {
                        _lastGeneratedInvoice = inv;
                      });
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: const Color(0xFF10B981),
                          content: Text('✅ eTIMS Invoice ${inv.invoiceNumber} recorded & local integrity hash verified!'),
                        ),
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.tealAccent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.verified_rounded, size: 20),
              label: Text('Generate & Validate eTIMS Invoice', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
        ],
      ),
    );

    final receiptPanel = _lastGeneratedInvoice == null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.receipt_long_rounded, color: Colors.white24, size: 64),
                  const SizedBox(height: 12),
                  Text('No Invoice Generated Yet', style: GoogleFonts.inter(color: Colors.white54, fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Add items and tap "Generate & Validate" to preview the eTIMS fiscal thermal layout.',
                      textAlign: TextAlign.center, style: GoogleFonts.inter(color: Colors.white38, fontSize: 12)),
                ],
              ),
            ),
          )
        : _buildOfficialKraReceiptWidget(_lastGeneratedInvoice!);

    if (isDesktop) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: formPanel),
            const SizedBox(width: 16),
            Expanded(flex: 2, child: receiptPanel),
          ],
        ),
      );
    } else {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            formPanel,
            const SizedBox(height: 16),
            receiptPanel,
          ],
        ),
      );
    }
  }

  Widget _buildTaxSummaryRow(String label, String value, Color valueColor, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(color: Colors.white70, fontSize: isBold ? 13 : 11, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: GoogleFonts.inter(color: valueColor, fontSize: isBold ? 14 : 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // Official 80mm KRA Fiscal Thermal Receipt Layout
  Widget _buildOfficialKraReceiptWidget(ETIMSInvoice inv) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('MEDIOCARE PHARMACY LTD', style: GoogleFonts.courierPrime(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black)),
          Text(inv.branchName.toUpperCase(), style: GoogleFonts.courierPrime(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
          Text('KRA PIN: ${inv.kraPin}', style: GoogleFonts.courierPrime(fontSize: 11, color: Colors.black87)),
          Text('DEVICE ID: ${inv.cuSerialNumber}', style: GoogleFonts.courierPrime(fontSize: 11, color: Colors.black87)),
          const Divider(color: Colors.black54, thickness: 1),
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('INVOICE NO: ${inv.invoiceNumber}', style: GoogleFonts.courierPrime(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black)),
                Text('CU INVOICE: ${inv.cuInvoiceNumber}', style: GoogleFonts.courierPrime(fontSize: 10, color: Colors.black87)),
                Text('DATE/TIME: ${DateFormat("yyyy-MM-dd HH:mm:ss").format(inv.dateTime)}', style: GoogleFonts.courierPrime(fontSize: 10, color: Colors.black87)),
                Text('BUYER: ${inv.customerName}', style: GoogleFonts.courierPrime(fontSize: 10, color: Colors.black87)),
                if (inv.customerPin != null && inv.customerPin!.isNotEmpty)
                  Text('BUYER PIN: ${inv.customerPin}', style: GoogleFonts.courierPrime(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black)),
                Text('PAYMENT: ${inv.paymentMode} (${inv.paymentReference})', style: GoogleFonts.courierPrime(fontSize: 10, color: Colors.black87)),
              ],
            ),
          ),
          const Divider(color: Colors.black54, thickness: 1),
          // Items
          Column(
            children: inv.items.map((i) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text('${i.quantity}x ${i.itemName} [${i.taxCode.code}]',
                          style: GoogleFonts.courierPrime(fontSize: 10, color: Colors.black), overflow: TextOverflow.ellipsis),
                    ),
                    Text(NumberFormat("#,##0.00").format(i.grossTotal), style: GoogleFonts.courierPrime(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black)),
                  ],
                ),
              );
            }).toList(),
          ),
          const Divider(color: Colors.black54, thickness: 1),
          // Tax Breakdowns
          _buildReceiptLine('TAXABLE B (16% VAT):', 'KES ${NumberFormat("#,##0.00").format(inv.totalTaxableB)}'),
          _buildReceiptLine('VAT AMOUNT B (16%):', 'KES ${NumberFormat("#,##0.00").format(inv.totalTaxB)}'),
          _buildReceiptLine('EXEMPT A (0%):', 'KES ${NumberFormat("#,##0.00").format(inv.totalTaxableA)}'),
          _buildReceiptLine('ZERO-RATED C (0%):', 'KES ${NumberFormat("#,##0.00").format(inv.totalTaxableC)}'),
          if (inv.totalTaxableD > 0) _buildReceiptLine('NON-VAT D (0%):', 'KES ${NumberFormat("#,##0.00").format(inv.totalTaxableD)}'),
          if (inv.totalTaxableE > 0) _buildReceiptLine('TAXABLE E (8% VAT):', 'KES ${NumberFormat("#,##0.00").format(inv.totalTaxableE)}'),
          if (inv.totalTaxE > 0) _buildReceiptLine('VAT AMOUNT E (8%):', 'KES ${NumberFormat("#,##0.00").format(inv.totalTaxE)}'),
          _buildReceiptLine('TOTAL VAT COLLECTED:', 'KES ${NumberFormat("#,##0.00").format(inv.totalTax)}'),
          const SizedBox(height: 4),
          _buildReceiptLine('TOTAL AMOUNT PAYABLE:', 'KES ${NumberFormat("#,##0.00").format(inv.totalGross)}', isBold: true),
          const Divider(color: Colors.black54, thickness: 1),
          // QR Code Verification
          const SizedBox(height: 6),
          Center(
            child: QrImageView(
              data: inv.verificationUrl,
              version: QrVersions.auto,
              size: 130.0,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text('LOCAL INTEGRITY PRE-VALIDATION HASH:', style: GoogleFonts.courierPrime(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black)),
          Text(inv.localIntegrityHash, style: GoogleFonts.courierPrime(fontSize: 8, color: Colors.black87), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text('[STATUS: PENDING KRA VSCU / OSCU DEVICE SIGNING]',
              style: GoogleFonts.courierPrime(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.red[800]), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text('*** MEDIOCARE PHARMACY TAX INVOICE ***', style: GoogleFonts.courierPrime(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black)),
        ],
      ),
    );
  }

  Widget _buildReceiptLine(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.courierPrime(fontSize: isBold ? 11 : 9, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: Colors.black)),
        Text(value, style: GoogleFonts.courierPrime(fontSize: isBold ? 11 : 9, fontWeight: FontWeight.bold, color: Colors.black)),
      ],
    );
  }

  void _showAddItemModal() {
    final nameCtrl = TextEditingController();
    final skuCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    TIMSTaxCode selectedCode = TIMSTaxCode.B; // Strict default: Code B (16% Standard VAT)

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              title: Text('Add Invoice Line Item', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(labelText: 'Medicine / Item Name', labelStyle: TextStyle(color: Colors.white54)),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: skuCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(labelText: 'SKU / Barcode', labelStyle: TextStyle(color: Colors.white54)),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: qtyCtrl,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: const InputDecoration(labelText: 'Quantity', labelStyle: TextStyle(color: Colors.white54)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: priceCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: const InputDecoration(labelText: 'Unit Price (KES)', labelStyle: TextStyle(color: Colors.white54)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<TIMSTaxCode>(
                      key: ValueKey(selectedCode),
                      initialValue: selectedCode,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(labelText: 'KRA Tax Code', labelStyle: TextStyle(color: Colors.white54)),
                      items: TIMSTaxCode.values.map((tc) {
                        return DropdownMenuItem<TIMSTaxCode>(
                          value: tc,
                          child: Text('${tc.code} - ${tc.description}'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedCode = val);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  onPressed: () {
                    final qty = int.tryParse(qtyCtrl.text) ?? 1;
                    final price = double.tryParse(priceCtrl.text) ?? 0.0;
                    if (nameCtrl.text.trim().isNotEmpty) {
                      setState(() {
                        _draftItems.add(ETIMSLineItem(
                          drugId: 'drug-${DateTime.now().millisecondsSinceEpoch}',
                          itemName: nameCtrl.text.trim(),
                          sku: skuCtrl.text.trim(),
                          quantity: qty,
                          unitPrice: price,
                          taxCode: selectedCode,
                        ));
                      });
                    }
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black),
                  child: const Text('Add to Invoice'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // TAB 2: Signed e-Invoices Register
  // ===========================================================================
  Widget _buildInvoicesRegisterTab(bool isDesktop, ETIMSService etims) {
    final invoices = etims.invoices;

    return Padding(
      padding: EdgeInsets.all(isDesktop ? 20.0 : 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('KRA eTIMS Validated Invoices (${invoices.length})',
                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('eTIMS Register Active',
                    style: GoogleFonts.inter(color: const Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold)),
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
              child: invoices.isEmpty
                  ? Center(child: Text('No validated invoices recorded in database.', style: GoogleFonts.inter(color: Colors.white54)))
                  : ListView.separated(
                      itemCount: invoices.length,
                      separatorBuilder: (_, _) => Divider(color: Colors.white.withValues(alpha: 0.05), height: 1),
                      itemBuilder: (context, idx) {
                        final inv = invoices[idx];

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.tealAccent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.receipt_rounded, color: Colors.tealAccent, size: 22),
                          ),
                          title: Text(inv.invoiceNumber, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${inv.branchName} • Buyer: ${inv.customerName} • ${DateFormat("yyyy-MM-dd HH:mm").format(inv.dateTime)}',
                                  style: GoogleFonts.inter(color: Colors.white54, fontSize: 11)),
                              const SizedBox(height: 2),
                              Text('CU Invoice: ${inv.cuInvoiceNumber} • VAT: KES ${NumberFormat("#,##0.00").format(inv.totalTax)}',
                                  style: GoogleFonts.inter(color: Colors.tealAccent, fontSize: 10)),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'KES ${NumberFormat("#,##0.00").format(inv.totalGross)}',
                                style: GoogleFonts.inter(color: Colors.tealAccent, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.qr_code_2_rounded, color: Colors.white70),
                                tooltip: 'View Fiscal Receipt',
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      backgroundColor: const Color(0xFF0F172A),
                                      content: SingleChildScrollView(
                                        child: SizedBox(
                                          width: 380,
                                          child: _buildOfficialKraReceiptWidget(inv),
                                        ),
                                      ),
                                    ),
                                  );
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

  // ===========================================================================
  // TAB 3: Daily Z-Report & Tax Counter
  // ===========================================================================
  Widget _buildDailyZReportTab(bool isDesktop, ETIMSService etims) {
    final zReports = etims.zReports;

    return Padding(
      padding: EdgeInsets.all(isDesktop ? 20.0 : 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Daily Z-Report & End of Day Tax Audit',
                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ElevatedButton.icon(
                onPressed: () async {
                  final z = await etims.generateDailyZReport(
                    branchName: etims.selectedBranch,
                    branchId: etims.selectedBranchId,
                    date: DateTime.now(),
                    supervisorName: 'Dr. Faith Mutua (Superintendent)',
                  );
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: Colors.teal,
                      content: Text('✅ Generated Z-Report ${z.zReportNumber} for ${z.branchName}!'),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent, foregroundColor: Colors.black),
                icon: const Icon(Icons.summarize_rounded, size: 18),
                label: Text('Generate Today\'s Z-Report', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: zReports.isEmpty
                ? Center(child: Text('No Z-Reports generated yet in database.', style: GoogleFonts.inter(color: Colors.white54)))
                : ListView.separated(
                    itemCount: zReports.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, idx) {
                      final z = zReports[idx];

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.amberAccent.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(Icons.assignment_turned_in_rounded, color: Colors.amberAccent, size: 18),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(z.zReportNumber, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text('Status: FINALIZED & TRANSMITTED',
                                      style: GoogleFonts.inter(color: const Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 20,
                              runSpacing: 6,
                              children: [
                                Text('Branch: ${z.branchName}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                Text('Date: ${DateFormat("yyyy-MM-dd").format(z.date)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                Text('Invoice Range: ${z.startInvoiceNumber} ➔ ${z.endInvoiceNumber}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                Text('Total Invoices: ${z.totalInvoices}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Wrap(
                                spacing: 24,
                                runSpacing: 8,
                                children: [
                                  _buildZReportStat('Gross Turnover', 'KES ${NumberFormat("#,##0.00").format(z.grossSales)}', Colors.tealAccent),
                                  _buildZReportStat('Code B (16% VAT)', 'KES ${NumberFormat("#,##0.00").format(z.taxCodeBTax)}', Colors.tealAccent),
                                  _buildZReportStat('Code A (Exempt)', 'KES ${NumberFormat("#,##0.00").format(z.taxCodeASales)}', Colors.purpleAccent),
                                  _buildZReportStat('Code C (Zero-Rated)', 'KES ${NumberFormat("#,##0.00").format(z.taxCodeCSales)}', Colors.cyanAccent),
                                  _buildZReportStat('Total VAT Output', 'KES ${NumberFormat("#,##0.00").format(z.totalTax)}', Colors.amberAccent),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text('Supervisor Sign-off: ${z.supervisorSignOff}',
                                style: GoogleFonts.inter(color: Colors.white54, fontSize: 11, fontStyle: FontStyle.italic)),
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

  Widget _buildZReportStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(color: Colors.white54, fontSize: 10)),
        const SizedBox(height: 2),
        Text(value, style: GoogleFonts.inter(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // ===========================================================================
  // TAB 4: Branch Till & Cash Drawer Reconciliation
  // ===========================================================================
  Widget _buildTillReconciliationTab(bool isDesktop, ETIMSService etims) {
    final double openFloat = double.tryParse(_floatCtrl.text) ?? 0.0;
    final double cash = double.tryParse(_cashSalesCtrl.text) ?? 0.0;
    final double mpesa = double.tryParse(_mpesaSalesCtrl.text) ?? 0.0;
    final double card = double.tryParse(_cardSalesCtrl.text) ?? 0.0;
    final double insurance = double.tryParse(_insuranceSalesCtrl.text) ?? 0.0;
    final double petty = double.tryParse(_pettyCashCtrl.text) ?? 0.0;
    final double actualCash = double.tryParse(_actualCashCtrl.text) ?? 0.0;

    final expectedCash = openFloat + cash - petty;
    final variance = actualCash - expectedCash;
    final totalTurnover = cash + mpesa + card + insurance;

    final reconciliationForm = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Shift End Cash Drawer Balancing', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.tealAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('Active Branch: ${etims.selectedBranch}',
                    style: GoogleFonts.inter(color: Colors.tealAccent, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: isDesktop ? 180 : double.infinity,
                child: TextField(
                  controller: _floatCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Opening Cash Float (KES)',
                    labelStyle: TextStyle(color: Colors.white54, fontSize: 11),
                    filled: true,
                    fillColor: Color(0xFF1E293B),
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                  ),
                ),
              ),
              SizedBox(
                width: isDesktop ? 180 : double.infinity,
                child: TextField(
                  controller: _cashSalesCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Cash Intake (KES)',
                    labelStyle: TextStyle(color: Colors.white54, fontSize: 11),
                    filled: true,
                    fillColor: Color(0xFF1E293B),
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                  ),
                ),
              ),
              SizedBox(
                width: isDesktop ? 180 : double.infinity,
                child: TextField(
                  controller: _mpesaSalesCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'M-Pesa Till Receipts (KES)',
                    labelStyle: TextStyle(color: Colors.white54, fontSize: 11),
                    filled: true,
                    fillColor: Color(0xFF1E293B),
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                  ),
                ),
              ),
              SizedBox(
                width: isDesktop ? 180 : double.infinity,
                child: TextField(
                  controller: _cardSalesCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Card Terminal Slips (KES)',
                    labelStyle: TextStyle(color: Colors.white54, fontSize: 11),
                    filled: true,
                    fillColor: Color(0xFF1E293B),
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                  ),
                ),
              ),
              SizedBox(
                width: isDesktop ? 180 : double.infinity,
                child: TextField(
                  controller: _insuranceSalesCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Insurance / SHA (KES)',
                    labelStyle: TextStyle(color: Colors.white54, fontSize: 11),
                    filled: true,
                    fillColor: Color(0xFF1E293B),
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                  ),
                ),
              ),
              SizedBox(
                width: isDesktop ? 180 : double.infinity,
                child: TextField(
                  controller: _pettyCashCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Petty Cash Payouts (KES)',
                    labelStyle: TextStyle(color: Colors.white54, fontSize: 11),
                    filled: true,
                    fillColor: Color(0xFF1E293B),
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                  ),
                ),
              ),
              SizedBox(
                width: isDesktop ? 180 : double.infinity,
                child: TextField(
                  controller: _actualCashCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Physical Cash Count (KES)',
                    labelStyle: TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold),
                    filled: true,
                    fillColor: Color(0xFF1E293B),
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _notesCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Reconciliation Notes / G4S Transit Reference',
              labelStyle: TextStyle(color: Colors.white54, fontSize: 11),
              filled: true,
              fillColor: Color(0xFF1E293B),
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
            ),
          ),
          const SizedBox(height: 16),

          // Real-time Variance Analysis Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF132043),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: variance.abs() < 1.0
                    ? const Color(0xFF10B981)
                    : variance < 0
                        ? Colors.redAccent
                        : Colors.amberAccent,
              ),
            ),
            child: Column(
              children: [
                _buildReconMetricRow('Total Shift Turnover (All Channels):', 'KES ${NumberFormat("#,##0.00").format(totalTurnover)}', Colors.tealAccent),
                _buildReconMetricRow('Expected Cash in Drawer:', 'KES ${NumberFormat("#,##0.00").format(expectedCash)}', Colors.white),
                _buildReconMetricRow('Physical Cash Counted:', 'KES ${NumberFormat("#,##0.00").format(actualCash)}', Colors.white),
                const Divider(color: Colors.white24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('DRAWER RECONCILIATION VARIANCE:', style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: variance.abs() < 1.0
                            ? const Color(0xFF10B981).withValues(alpha: 0.2)
                            : variance < 0
                                ? Colors.redAccent.withValues(alpha: 0.2)
                                : Colors.amberAccent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        variance.abs() < 1.0
                            ? 'BALANCED (KES 0.00)'
                            : variance < 0
                                ? 'SHORTAGE: -KES ${NumberFormat("#,##0.00").format(variance.abs())}'
                                : 'SURPLUS: +KES ${NumberFormat("#,##0.00").format(variance)}',
                        style: TextStyle(
                          color: variance.abs() < 1.0
                              ? const Color(0xFF10B981)
                              : variance < 0
                                  ? Colors.redAccent
                                  : Colors.amberAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Submit Reconciliation Sign-Off
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: () async {
                final session = await etims.reconcileTillSession(
                  branchName: etims.selectedBranch,
                  branchId: etims.selectedBranchId,
                  cashierName: _cashierCtrl.text.trim().isEmpty ? 'Cashier 01' : _cashierCtrl.text.trim(),
                  openingFloat: openFloat,
                  cashSales: cash,
                  mpesaSales: mpesa,
                  cardSales: card,
                  insuranceSales: insurance,
                  pettyCashPayouts: petty,
                  actualCashInDrawer: actualCash,
                  managerNotes: _notesCtrl.text.trim(),
                );
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFF10B981),
                    content: Text('✅ Shift till session ${session.sessionId} reconciled and audited!'),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black),
              icon: const Icon(Icons.lock_clock_rounded, size: 18),
              label: Text('Finalize Shift & Sign Off Till', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
        ],
      ),
    );

    final historyPanel = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Branch Till Audit Log (${etims.tillSessions.length})',
              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          etims.tillSessions.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: Center(child: Text('No till sessions recorded in database.', style: GoogleFonts.inter(color: Colors.white54))),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: etims.tillSessions.length,
                  separatorBuilder: (_, _) => Divider(color: Colors.white.withValues(alpha: 0.05)),
                  itemBuilder: (context, idx) {
                    final s = etims.tillSessions[idx];
                    final isBalanced = s.isBalanced;

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        isBalanced ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                        color: isBalanced ? const Color(0xFF10B981) : Colors.amberAccent,
                      ),
                      title: Text(s.sessionId, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      subtitle: Text('${s.branchName} • Cashier: ${s.cashierName} • Total: KES ${NumberFormat("#,##0").format(s.totalRevenue)}',
                          style: const TextStyle(color: Colors.white54, fontSize: 10)),
                      trailing: Text(
                        s.isBalanced ? 'Balanced' : 'Var: KES ${NumberFormat("#,##0").format(s.variance)}',
                        style: TextStyle(
                          color: s.isBalanced ? const Color(0xFF10B981) : Colors.amberAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );

    if (isDesktop) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: reconciliationForm),
            const SizedBox(width: 16),
            Expanded(flex: 2, child: historyPanel),
          ],
        ),
      );
    } else {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            reconciliationForm,
            const SizedBox(height: 16),
            historyPanel,
          ],
        ),
      );
    }
  }

  Widget _buildReconMetricRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(color: Colors.white70, fontSize: 11)),
          Text(value, style: GoogleFonts.inter(color: valueColor, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

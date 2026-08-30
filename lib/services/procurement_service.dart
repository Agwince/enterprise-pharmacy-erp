import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../models/purchase_order.dart';
import '../models/drug.dart';
import '../models/etims_invoice.dart';
import 'accounting_service.dart';
import 'supabase_service.dart';

class ProcurementService extends ChangeNotifier {
  final SupabaseClient? _client;
  final AccountingService _accountingService;
  final SupabaseService _supabaseService;

  bool _loading = false;
  bool _schemaMissing = false;
  String? _error;

  List<Supplier> _suppliers = [];
  List<PurchaseOrder> _purchaseOrders = [];
  List<Drug> _drugs = [];
  List<Map<String, dynamic>> _abcItems = [];

  String _selectedBranchId = 'nbo-hq-001';
  String _selectedBranchName = 'Nairobi HQ';

  final List<Map<String, String>> branches = [
    {'name': 'Nairobi HQ', 'id': 'nbo-hq-001'},
    {'name': 'Kisumu Bulk Hub', 'id': 'ksm-hub-002'},
    {'name': 'Mombasa Coastal Depot', 'id': 'mba-cst-003'},
    {'name': 'Eldoret Transit', 'id': 'eld-trn-004'},
  ];

  ProcurementService({
    SupabaseClient? client,
    AccountingService? accountingService,
    SupabaseService? supabaseService,
  })  : _client = client ?? (Supabase.instance.isInitialized ? Supabase.instance.client : null),
        _accountingService = accountingService ?? AccountingService(),
        _supabaseService = supabaseService ?? SupabaseService() {
    loadAll();
  }

  bool get loading => _loading;
  bool get schemaMissing => _schemaMissing;
  String? get error => _error;
  List<Supplier> get suppliers => _suppliers;
  List<PurchaseOrder> get purchaseOrders => _purchaseOrders;
  List<Drug> get drugs => _drugs;
  List<Map<String, dynamic>> get abcItems => _abcItems;
  String get selectedBranchId => _selectedBranchId;
  String get selectedBranchName => _selectedBranchName;

  void setSelectedBranch(String branchName) {
    final b = branches.firstWhere((e) => e['name'] == branchName, orElse: () => branches.first);
    _selectedBranchName = b['name']!;
    _selectedBranchId = b['id']!;
    notifyListeners();
  }

  Future<void> loadAll() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      if (_client != null) {
        // 1. Fetch Suppliers
        try {
          final supRes = await _client.from('suppliers').select().order('name');
          _suppliers = (supRes as List).map((r) => Supplier.fromJson(Map<String, dynamic>.from(r as Map))).toList();
          _schemaMissing = false;
        } catch (_) {
          _suppliers = [];
          _schemaMissing = true;
        }

        // 2. Fetch Drugs
        try {
          final drugRes = await _client.from('drugs').select().order('name').limit(500);
          _drugs = (drugRes as List).map((r) => Drug.fromJson(Map<String, dynamic>.from(r as Map))).toList();
        } catch (_) {
          _drugs = [];
        }

        // 3. Fetch Purchase Orders
        try {
          final poRes = await _client.from('purchase_orders').select('''
            *,
            purchase_order_items (
              *,
              drugs (name, sku)
            )
          ''').order('created_at', ascending: false).limit(100);

          _purchaseOrders = (poRes as List).map((r) => PurchaseOrder.fromJson(Map<String, dynamic>.from(r as Map))).toList();
        } catch (_) {
          _purchaseOrders = [];
        }

        // 4. Fetch ABC Analysis via RPC
        try {
          _abcItems = await _supabaseService.getAbcClassification(branchId: _selectedBranchId);
        } catch (_) {
          _abcItems = [];
        }
      } else {
        _schemaMissing = true;
        _suppliers = [];
        _purchaseOrders = [];
        _drugs = [];
        _abcItems = [];
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ===========================================================================
  // 1. SUPPLIERS CRUD
  // ===========================================================================
  Future<void> saveSupplier({
    String? id,
    required String name,
    String? code,
    String? kraPin,
    String? phone,
    String? email,
    String? contactPerson,
    String? paymentTerms,
    double? creditLimit,
    int? leadTimeDays,
  }) async {
    final Map<String, dynamic> payload = {
      'name': name.trim(),
      'is_active': true,
    };
    if (code != null && code.trim().isNotEmpty) payload['code'] = code.trim();
    if (kraPin != null && kraPin.trim().isNotEmpty) payload['kra_pin'] = kraPin.trim();
    if (phone != null && phone.trim().isNotEmpty) payload['phone'] = phone.trim();
    if (email != null && email.trim().isNotEmpty) payload['email'] = email.trim();
    if (contactPerson != null && contactPerson.trim().isNotEmpty) payload['contact_person'] = contactPerson.trim();
    if (paymentTerms != null && paymentTerms.trim().isNotEmpty) payload['payment_terms'] = paymentTerms.trim();
    if (creditLimit != null) payload['credit_limit'] = creditLimit;
    if (leadTimeDays != null) payload['lead_time_days'] = leadTimeDays;

    if (_client != null && !_schemaMissing) {
      if (id != null && id.isNotEmpty) {
        await _client.from('suppliers').update(payload).eq('id', id);
      } else {
        await _client.from('suppliers').insert(payload);
      }
    }

    await loadAll();
  }

  Future<void> deleteSupplier(String id) async {
    if (_client != null && !_schemaMissing) {
      await _client.from('suppliers').update({'is_active': false}).eq('id', id);
    }
    _suppliers.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  // ===========================================================================
  // 2. PURCHASE ORDERS (LPO) CREATION & LIFECYCLE
  // ===========================================================================
  Future<PurchaseOrder> createPurchaseOrder({
    required String branchId,
    required String branchName,
    String? supplierId,
    String? supplierName,
    DateTime? deliveryDate,
    String? notes,
    required List<Map<String, dynamic>> lineItems, // drug_id, quantity_requested, unit_cost, drug_name, drug_sku
  }) async {
    final now = DateTime.now();
    final poNumber = 'LPO-${DateFormat("yyyyMMdd").format(now)}-${(_purchaseOrders.length + 1).toString().padLeft(3, '0')}';
    final totalAmount = lineItems.fold(0.0, (sum, i) => sum + (((i['quantity_requested'] as num?)?.toInt() ?? 0) * ((i['unit_cost'] as num?)?.toDouble() ?? 0.0)));

    final Map<String, dynamic> poPayload = {
      'po_number': poNumber,
      'branch_id': branchId,
      'status': 'draft',
      'total_amount': totalAmount,
      'created_at': now.toIso8601String(),
      'match_status': 'UNMATCHED',
      'match_tolerance': 500.0,
    };
    if (supplierId != null) poPayload['supplier_id'] = supplierId;
    if (deliveryDate != null) poPayload['delivery_date'] = deliveryDate.toIso8601String().substring(0, 10);
    if (notes != null) poPayload['notes'] = notes;

    String poId = 'po-${now.millisecondsSinceEpoch}';

    if (_client != null && !_schemaMissing) {
      try {
        final inserted = await _client.from('purchase_orders').insert(poPayload).select().single();
        poId = inserted['id'].toString();

        final itemsPayload = lineItems.map((item) {
          return {
            'po_id': poId,
            'drug_id': item['drug_id'],
            'quantity_requested': (item['quantity_requested'] as num?)?.toInt() ?? 0,
            'quantity_received': 0,
            'unit_cost': (item['unit_cost'] as num?)?.toDouble() ?? 0.0,
          };
        }).toList();

        await _client.from('purchase_order_items').insert(itemsPayload);
      } catch (e) {
        debugPrint('PO Supabase Insert note: $e');
      }
    }

    await loadAll();
    return _purchaseOrders.firstWhere((p) => p.poNumber == poNumber, orElse: () => PurchaseOrder(
      id: poId,
      poNumber: poNumber,
      branchId: branchId,
      branchName: branchName,
      supplierId: supplierId,
      supplierName: supplierName,
      status: 'draft',
      totalAmount: totalAmount,
      createdAt: now,
      deliveryDate: deliveryDate,
      notes: notes,
      items: lineItems.map((i) => PurchaseOrderItem(
        id: 'item-${now.millisecondsSinceEpoch}',
        poId: poId,
        drugId: i['drug_id']?.toString() ?? '',
        quantityRequested: (i['quantity_requested'] as num?)?.toInt() ?? 0,
        quantityReceived: 0,
        unitCost: (i['unit_cost'] as num?)?.toDouble() ?? 0.0,
        drugName: i['drug_name']?.toString(),
        drugSku: i['drug_sku']?.toString(),
      )).toList(),
    ));
  }

  Future<void> updatePOStatus(String poId, String newStatus, {String? approvedBy}) async {
    final now = DateTime.now();
    final Map<String, dynamic> payload = {
      'status': newStatus.toLowerCase(),
    };
    if (approvedBy != null) {
      payload['approved_by'] = approvedBy;
      payload['approved_at'] = now.toIso8601String();
    }

    if (_client != null && !_schemaMissing) {
      try {
        await _client.from('purchase_orders').update(payload).eq('id', poId);
      } catch (e) {
        debugPrint('Update PO status note: $e');
      }
    }

    final idx = _purchaseOrders.indexWhere((p) => p.id == poId);
    if (idx != -1) {
      final old = _purchaseOrders[idx];
      _purchaseOrders[idx] = PurchaseOrder(
        id: old.id,
        poNumber: old.poNumber,
        branchId: old.branchId,
        branchName: old.branchName,
        supplierId: old.supplierId,
        supplierName: old.supplierName,
        status: newStatus.toLowerCase(),
        totalAmount: old.totalAmount,
        createdAt: old.createdAt,
        deliveryDate: old.deliveryDate,
        notes: old.notes,
        approvedBy: approvedBy ?? old.approvedBy,
        approvedAt: approvedBy != null ? now : old.approvedAt,
        grnNumber: old.grnNumber,
        grnDate: old.grnDate,
        receivedBy: old.receivedBy,
        invoiceNumber: old.invoiceNumber,
        invoiceAmount: old.invoiceAmount,
        matchStatus: old.matchStatus,
        matchTolerance: old.matchTolerance,
        glJournalId: old.glJournalId,
        glPaymentJournalId: old.glPaymentJournalId,
        items: old.items,
      );
      notifyListeners();
    }
  }

  // ===========================================================================
  // 3. GOODS RECEIVED NOTE (GRN) & GENUINE COST PRICE CAPTURE
  // ===========================================================================
  Future<Map<String, dynamic>> receiveGRN({
    required String poId,
    required String receivedBy,
    required List<Map<String, dynamic>> receivedItems, // id, drug_id, quantity_received, real_grn_cost, tax_code, batch_no, expiry_date
    double freightAmount = 0.0,
  }) async {
    final now = DateTime.now();
    final grnNumber = 'GRN-${DateFormat("yyyyMMdd").format(now)}-${DateFormat("HHmmss").format(now)}';
    final po = _purchaseOrders.firstWhere((p) => p.id == poId);

    double totalNetInventory = 0.0;
    double totalInputVat = 0.0;

    for (final item in receivedItems) {
      final qty = (item['quantity_received'] as num?)?.toInt() ?? 0;
      final netCost = (item['real_grn_cost'] as num?)?.toDouble() ?? 0.0;
      final lineNet = qty * netCost;
      totalNetInventory += lineNet;

      final taxCode = TIMSTaxCode.fromCode(item['tax_code']?.toString());
      if (taxCode.allowsInputCredit && taxCode.rate > 0.0) {
        totalInputVat += (lineNet * taxCode.rate);
      }
    }

    final totalGrossPayable = totalNetInventory + totalInputVat + freightAmount;

    String? postedJournalId;
    String? glStatusMessage;

    // GL POSTING ON GRN:
    // Dr Inventory (1300) [Net Asset Value excluding claimable VAT]
    // Dr VAT Recoverable - KRA Input Tax (2110) [Claimable Input VAT based on eTIMS tax code]
    // Dr Freight & Inward Logistics (5010) [Optional inbound landed charges]
    // Cr Accounts Payable / Trade Creditors (2000) [Gross payable invoice liability]
    try {
      if (totalGrossPayable > 0.0) {
        final List<JournalLineDraft> lines = [
          JournalLineDraft(
            accountCode: AccountingService.accInventory,
            debit: totalNetInventory,
            credit: 0.0,
            lineMemo: 'Inventory receipt at net cost for $grnNumber',
          ),
        ];

        if (totalInputVat > 0.0) {
          lines.add(JournalLineDraft(
            accountCode: AccountingService.accVatInput,
            debit: totalInputVat,
            credit: 0.0,
            lineMemo: 'KRA Input VAT claimable for $grnNumber',
          ));
        }

        if (freightAmount > 0.0) {
          lines.add(JournalLineDraft(
            accountCode: AccountingService.accFreightInward,
            debit: freightAmount,
            credit: 0.0,
            lineMemo: 'Inbound freight & carriage for $grnNumber',
          ));
        }

        lines.add(JournalLineDraft(
          accountCode: AccountingService.accPayables,
          debit: 0.0,
          credit: totalGrossPayable,
          lineMemo: 'Gross supplier payable for $grnNumber',
        ));

        postedJournalId = await _accountingService.postJournal(
          date: now,
          memo: 'GRN $grnNumber receipt from ${po.supplierName ?? "Supplier"} for PO ${po.poNumber}',
          reference: grnNumber,
          sourceModule: 'procurement',
          sourceId: poId,
          createdBy: receivedBy,
          lines: lines,
        );
        glStatusMessage = 'GL Posted: Dr 1300 (Net KES ${NumberFormat("#,##0.00").format(totalNetInventory)}) + Dr 2110 (VAT KES ${NumberFormat("#,##0.00").format(totalInputVat)}) / Cr 2000 (Gross KES ${NumberFormat("#,##0.00").format(totalGrossPayable)})';
      }
    } catch (e) {
      // GL failure must NEVER block physical goods receipt
      glStatusMessage = 'Physical goods received. (GL Posting deferred: $e)';
      debugPrint('GRN GL Posting Deferred: $e');
    }

    if (_client != null && !_schemaMissing) {
      try {
        // 1. Update PO with GRN metadata
        final Map<String, dynamic> poUpdate = {
          'status': 'received',
          'grn_number': grnNumber,
          'grn_date': now.toIso8601String(),
          'received_by': receivedBy,
        };
        if (postedJournalId != null) poUpdate['gl_journal_id'] = postedJournalId;

        await _client.from('purchase_orders').update(poUpdate).eq('id', poId);

        // 2. Update line items, increment real on-hand stock and insert inventory batches
        for (final item in receivedItems) {
          final itemId = item['id']?.toString();
          final drugId = item['drug_id']?.toString();
          final batchNo = item['batch_no']?.toString() ?? 'BATCH-${DateFormat("yyyyMM").format(now)}';
          final expiryStr = item['expiry_date']?.toString();
          final qtyRec = (item['quantity_received'] as num?)?.toInt() ?? 0;
          final realCost = (item['real_grn_cost'] as num?)?.toDouble() ?? 0.0;
          final taxCodeStr = item['tax_code']?.toString() ?? 'B';

          if (itemId != null && itemId.isNotEmpty) {
            await _client.from('purchase_order_items').update({
              'quantity_received': qtyRec,
              'unit_cost': realCost,
              'tax_code': taxCodeStr,
            }).eq('id', itemId);
          }

          if (drugId != null && qtyRec > 0) {
            // A. Increment on-hand stock in drugs catalog & update real cost price
            try {
              final drugRow = await _client.from('drugs').select('quantity_in_stock, warehouse_quantity').eq('id', drugId).maybeSingle();
              if (drugRow != null) {
                final currentStock = (drugRow['quantity_in_stock'] as num?)?.toInt() ?? 0;
                final currentWhStock = (drugRow['warehouse_quantity'] as num?)?.toInt() ?? 0;
                await _client.from('drugs').update({
                  'quantity_in_stock': currentStock + qtyRec,
                  'warehouse_quantity': currentWhStock + qtyRec,
                  'cost_price': realCost,
                }).eq('id', drugId);
              }
            } catch (e) {
              debugPrint('Stock increment on drugs table note: $e');
            }

            // B. Upsert into public.inventory table (branch level stock)
            try {
              await _client.from('inventory').upsert({
                'branch_id': po.branchId,
                'drug_id': drugId,
                'batch_number': batchNo,
                'quantity': qtyRec,
                'expiry_date': expiryStr ?? DateTime.now().add(const Duration(days: 540)).toIso8601String().substring(0, 10),
                'last_updated': now.toIso8601String(),
              }, onConflict: 'branch_id,drug_id,batch_number');
            } catch (e) {
              debugPrint('Inventory upsert note: $e');
            }

            // C. Insert into public.inventory_batches table (FEFO batch ledger)
            final Map<String, dynamic> batchPayload = {
              'drug_id': drugId,
              'branch_id': po.branchId,
              'batch_no': batchNo,
              'quantity': qtyRec,
              'cost_price': realCost,
              'grn_no': grnNumber,
              'received_at': now.toIso8601String(),
              'status': 'RELEASED',
            };
            if (expiryStr != null && expiryStr.isNotEmpty) batchPayload['expiry_date'] = expiryStr;
            await _client.from('inventory_batches').insert(batchPayload);
          }
        }
      } catch (e) {
        debugPrint('GRN Supabase update note: $e');
      }
    }

    await loadAll();
    return {
      'grn_number': grnNumber,
      'total_net': totalNetInventory,
      'total_vat': totalInputVat,
      'total_gross': totalGrossPayable,
      'journal_id': postedJournalId,
      'message': glStatusMessage,
    };
  }

  // ===========================================================================
  // 4. THREE-WAY INVOICE MATCHING (LPO vs GRN vs INVOICE)
  // ===========================================================================
  Future<String> matchSupplierInvoice({
    required String poId,
    required String invoiceNumber,
    required double invoiceAmount,
    double tolerance = 500.0,
  }) async {
    final po = _purchaseOrders.firstWhere((p) => p.id == poId);
    final grnTotal = po.grnTotalCost;
    final poTotal = po.totalAmount;

    String matchStatus = 'MATCHED';

    if (!po.isReceived && po.grnNumber == null) {
      matchStatus = 'BLOCKED'; // Cannot match an unreceived PO
    } else {
      final amountDiff = (invoiceAmount - (grnTotal > 0 ? grnTotal : poTotal)).abs();
      if (amountDiff > tolerance) {
        // Determine if price variance or quantity variance
        bool hasQtyDiff = po.items.any((i) => i.quantityReceived != i.quantityRequested);
        matchStatus = hasQtyDiff ? 'QTY_VARIANCE' : 'PRICE_VARIANCE';
      }
    }

    if (_client != null && !_schemaMissing) {
      try {
        await _client.from('purchase_orders').update({
          'invoice_number': invoiceNumber,
          'invoice_amount': invoiceAmount,
          'match_status': matchStatus,
          'match_tolerance': tolerance,
        }).eq('id', poId);
      } catch (e) {
        debugPrint('3-Way Match Update note: $e');
      }
    }

    await loadAll();
    return matchStatus;
  }

  // ===========================================================================
  // 5. SUPPLIER PAYMENT & GL SETTLEMENT
  // ===========================================================================
  Future<Map<String, dynamic>> paySupplierInvoice({
    required String poId,
    required double paymentAmount,
    String paymentMethod = 'Bank Transfer',
  }) async {
    final now = DateTime.now();
    final po = _purchaseOrders.firstWhere((p) => p.id == poId);

    String? paymentJournalId;
    String? glMessage;

    // GL POSTING ON PAYMENT:
    // Dr Accounts Payable (2000)
    // Cr Bank (1030) / M-Pesa (1020)
    try {
      paymentJournalId = await _accountingService.postJournal(
        date: now,
        memo: 'Payment to ${po.supplierName ?? "Supplier"} for Inv ${po.invoiceNumber ?? po.poNumber}',
        reference: po.invoiceNumber ?? po.poNumber,
        sourceModule: 'procurement',
        sourceId: poId,
        lines: [
          JournalLineDraft(
            accountCode: AccountingService.accPayables,
            debit: paymentAmount,
            credit: 0.0,
            lineMemo: 'Clear payables liability for ${po.invoiceNumber ?? po.poNumber}',
          ),
          JournalLineDraft(
            accountCode: paymentMethod == 'Cash' ? AccountingService.accCash : AccountingService.accBank,
            debit: 0.0,
            credit: paymentAmount,
            lineMemo: '$paymentMethod settlement for ${po.poNumber}',
          ),
        ],
      );
      glMessage = 'GL Posted: Dr Payables (2000) / Cr Bank (1030) for KES ${NumberFormat("#,##0.00").format(paymentAmount)}';
    } catch (e) {
      glMessage = 'Payment recorded. (GL Posting deferred: $e)';
      debugPrint('Payment GL Posting Deferred: $e');
    }

    if (_client != null && !_schemaMissing) {
      try {
        final Map<String, dynamic> closePayload = {'status': 'closed'};
        if (paymentJournalId != null) closePayload['gl_payment_journal_id'] = paymentJournalId;

        await _client.from('purchase_orders').update(closePayload).eq('id', poId);
      } catch (e) {
        debugPrint('Close PO note: $e');
      }
    }

    await loadAll();
    return {
      'journal_id': paymentJournalId,
      'message': glMessage,
    };
  }

  // ===========================================================================
  // 6. ABC VELOCITY & AUTO-DRAFT PO RPC REUSE
  // ===========================================================================
  Future<Map<String, dynamic>> autoDraftFromReplenishment() async {
    _loading = true;
    notifyListeners();

    try {
      final res = await _supabaseService.autoDraftPurchaseOrders(branchId: _selectedBranchId);
      await loadAll();
      return res;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}

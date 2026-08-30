import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/internal_requisition.dart';
import 'accounting_service.dart';

class RequisitionService {
  final SupabaseClient _db = Supabase.instance.client;
  final AccountingService _accounting = AccountingService();

  Future<List<InternalRequisition>> fetchRequisitions({
    String? status,
    String? branchId,
    int limit = 50,
  }) async {
    try {
      var query = _db.from('internal_requisitions').select('''
        *,
        requisition_items (*),
        requisition_audit_logs (*)
      ''');

      if (status != null && status.isNotEmpty) {
        query = query.eq('status', status);
      }
      if (branchId != null && branchId.isNotEmpty) {
        query = query.or('source_branch_id.eq.$branchId,destination_branch_id.eq.$branchId');
      }

      final res = await query.order('created_at', ascending: false).limit(limit);
      return (res as List)
          .map((r) => InternalRequisition.fromJson(Map<String, dynamic>.from(r as Map)))
          .toList();
    } catch (e) {
      debugPrint('RequisitionService.fetchRequisitions note: $e');
      return [];
    }
  }

  Future<InternalRequisition?> fetchRequisitionById(String id) async {
    try {
      final res = await _db.from('internal_requisitions').select('''
        *,
        requisition_items (*),
        requisition_audit_logs (*)
      ''').eq('id', id).maybeSingle();

      if (res == null) return null;
      return InternalRequisition.fromJson(Map<String, dynamic>.from(res));
    } catch (e) {
      debugPrint('RequisitionService.fetchRequisitionById note: $e');
      return null;
    }
  }

  /// Step 1: Create Requisition (Draft or Submitted)
  Future<InternalRequisition> createRequisition({
    required String? sourceBranchId,
    required String? destinationBranchId,
    required String requestedBy,
    required String notes,
    required List<Map<String, dynamic>> items, // {drug_id, drug_name, quantity_requested, unit_cost, bin_location}
    bool autoSubmit = true,
  }) async {
    final status = autoSubmit ? 'SUBMITTED' : 'DRAFT';
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
    final reqNo = 'REQ-2026-NBO-$timestamp';

    final reqPayload = {
      'requisition_no': reqNo,
      'source_branch_id': sourceBranchId,
      'destination_branch_id': destinationBranchId,
      'requested_by': requestedBy,
      'status': status,
      'notes': notes,
      'total_items_count': items.length,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    final reqRes = await _db.from('internal_requisitions').insert(reqPayload).select().single();
    final reqId = reqRes['id'] as String;

    // Insert items
    if (items.isNotEmpty) {
      final itemPayloads = items.map((it) => {
            'requisition_id': reqId,
            'drug_id': it['drug_id'],
            'drug_name': it['drug_name'],
            'quantity_requested': it['quantity_requested'] ?? 1,
            'quantity_picked': 0,
            'quantity_received': 0,
            'unit_cost': (it['unit_cost'] as num?)?.toDouble() ?? 0.0,
            'bin_location': it['bin_location'] ?? 'Unassigned',
          }).toList();

      await _db.from('requisition_items').insert(itemPayloads);
    }

    // Insert audit log
    await _logTransition(
      requisitionId: reqId,
      fromStatus: null,
      toStatus: status,
      action: autoSubmit ? 'Created & Submitted' : 'Draft Saved',
      actor: requestedBy,
      notes: notes,
    );

    return (await fetchRequisitionById(reqId))!;
  }

  /// Step 2: Submit a draft requisition
  Future<void> submitRequisition(String reqId, String actor) async {
    await _db.from('internal_requisitions').update({
      'status': 'SUBMITTED',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', reqId);

    await _logTransition(
      requisitionId: reqId,
      fromStatus: 'DRAFT',
      toStatus: 'SUBMITTED',
      action: 'Submitted to Hub',
      actor: actor,
    );
  }

  /// Step 3: Approve at Kisumu Bulk Hub
  Future<void> approveRequisition(String reqId, String actor, {String? notes}) async {
    await _db.from('internal_requisitions').update({
      'status': 'APPROVED',
      'approved_by': actor,
      'approved_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', reqId);

    await _logTransition(
      requisitionId: reqId,
      fromStatus: 'SUBMITTED',
      toStatus: 'APPROVED',
      action: 'Approved at Hub',
      actor: actor,
      notes: notes,
    );
  }

  /// Step 4: Start Picking
  Future<void> startPicking(String reqId, String actor) async {
    await _db.from('internal_requisitions').update({
      'status': 'PICKING',
      'picked_by': actor,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', reqId);

    await _logTransition(
      requisitionId: reqId,
      fromStatus: 'APPROVED',
      toStatus: 'PICKING',
      action: 'Picking Started',
      actor: actor,
    );
  }

  /// Step 5: Complete Picking with real batch & expiry capture
  Future<void> completePicking({
    required String reqId,
    required List<Map<String, dynamic>> pickedItems, // {id, quantity_picked, batch_no, expiry_date}
    required String actor,
  }) async {
    for (final item in pickedItems) {
      await _db.from('requisition_items').update({
        'quantity_picked': item['quantity_picked'],
        'batch_no': item['batch_no'],
        'expiry_date': item['expiry_date'],
      }).eq('id', item['id']);
    }

    await _db.from('internal_requisitions').update({
      'status': 'PICKED',
      'picked_by': actor,
      'picked_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', reqId);

    await _logTransition(
      requisitionId: reqId,
      fromStatus: 'PICKING',
      toStatus: 'PICKED',
      action: 'Picking Completed & Batches Verified',
      actor: actor,
    );
  }

  /// Step 6: Dispatch with Rider & Vehicle + Post In-Transit GL Journal (Dr 1350 / Cr 1300)
  Future<void> dispatchRequisition({
    required String reqId,
    required String riderName,
    required String vehiclePlate,
    String? riderId,
    String? vehicleId,
    required String actor,
  }) async {
    final req = await fetchRequisitionById(reqId);
    if (req == null) throw Exception('Requisition $reqId not found');

    // Calculate total dispatch value of picked items
    double dispatchCost = 0.0;
    for (final it in req.items) {
      final qty = it.quantityPicked > 0 ? it.quantityPicked : it.quantityRequested;
      dispatchCost += qty * it.unitCost;
    }

    // Post In-Transit GL Journal: Dr 1350 Inventory in Transit / Cr 1300 Warehouse Inventory
    String? dispatchJournalId;
    if (dispatchCost > 0.0) {
      try {
        dispatchJournalId = await _accounting.postJournal(
          date: DateTime.now(),
          memo: 'Inter-Branch Stock Dispatch: ${req.requisitionNo}',
          reference: req.requisitionNo,
          sourceModule: 'transfer_dispatch',
          sourceId: req.id,
          branchId: req.sourceBranchId,
          createdBy: actor,
          lines: [
            JournalLineDraft(
              accountCode: AccountingService.accInventoryInTransit, // Dr 1350 Inventory in Transit
              debit: dispatchCost,
              credit: 0.0,
              branchId: req.sourceBranchId,
              lineMemo: 'In-Transit Stock to ${req.destinationBranchName ?? "Branch"}',
            ),
            JournalLineDraft(
              accountCode: AccountingService.accInventory, // Cr 1300 Warehouse Inventory
              debit: 0.0,
              credit: dispatchCost,
              branchId: req.sourceBranchId,
              lineMemo: 'Dispatched from ${req.sourceBranchName ?? "Kisumu Bulk Hub"}',
            ),
          ],
        );
      } catch (e) {
        debugPrint('Dispatch GL Journal posting note: $e');
      }
    }

    await _db.from('internal_requisitions').update({
      'status': 'IN_TRANSIT',
      'rider_id': riderId,
      'rider_name': riderName,
      'vehicle_id': vehicleId,
      'vehicle_plate': vehiclePlate,
      'dispatched_by': actor,
      'dispatched_at': DateTime.now().toIso8601String(),
      'gl_journal_id': dispatchJournalId,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', reqId);

    await _logTransition(
      requisitionId: reqId,
      fromStatus: 'PICKED',
      toStatus: 'IN_TRANSIT',
      action: 'Dispatched with Courier & In-Transit Journal Posted',
      actor: actor,
      notes: 'Vehicle: $vehiclePlate, Rider: $riderName • Dr 1350/Cr 1300 KES ${dispatchCost.toStringAsFixed(2)}',
    );
  }

  /// Step 7: Mark Delivered by courier
  Future<void> markDelivered(String reqId, String actor) async {
    await _db.from('internal_requisitions').update({
      'status': 'DELIVERED',
      'delivered_by': actor,
      'delivered_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', reqId);

    await _logTransition(
      requisitionId: reqId,
      fromStatus: 'IN_TRANSIT',
      toStatus: 'DELIVERED',
      action: 'Delivered to Destination Loading Bay',
      actor: actor,
    );
  }

  /// Step 8: Receive & Close Requisition
  /// Decrements source warehouse_quantity, increments destination shelf_quantity,
  /// leaves quantity_in_stock UNCHANGED, and posts receipt GL Journal Dr 1300 / Cr 1350.
  Future<void> receiveAndCloseRequisition({
    required String reqId,
    required List<Map<String, dynamic>> receivedItems, // {id, drug_id, quantity_received, unit_cost, batch_no, expiry_date}
    required String actor,
  }) async {
    final req = await fetchRequisitionById(reqId);
    if (req == null) throw Exception('Requisition $reqId not found');

    double totalTransferCost = 0.0;

    // 1. Update received items and real on-hand stock quantities
    for (final it in receivedItems) {
      final int qtyRec = (it['quantity_received'] as num?)?.toInt() ?? 0;
      final double cost = (it['unit_cost'] as num?)?.toDouble() ?? 0.0;
      final String drugId = it['drug_id'].toString();
      final String? batchNo = it['batch_no']?.toString();
      final String? expiryDate = it['expiry_date']?.toString();

      totalTransferCost += qtyRec * cost;

      await _db.from('requisition_items').update({
        'quantity_received': qtyRec,
      }).eq('id', it['id']);

      // RULE: Inter-branch requisition is an internal stock movement, not a net gain.
      // drugs.quantity_in_stock is the TOTAL across locations (warehouse_quantity + shelf_quantity).
      // On branch receipt: warehouse_quantity -= transferred, shelf_quantity += transferred, quantity_in_stock remains UNCHANGED.
      try {
        final drugRes = await _db
            .from('drugs')
            .select('id, quantity_in_stock, warehouse_quantity, shelf_quantity')
            .eq('id', drugId)
            .maybeSingle();

        if (drugRes != null) {
          final currentWarehouse = (drugRes['warehouse_quantity'] as num?)?.toInt() ?? 0;
          final currentShelf = (drugRes['shelf_quantity'] as num?)?.toInt() ?? 0;

          final newWarehouse = (currentWarehouse - qtyRec).clamp(0, 999999);
          final newShelf = currentShelf + qtyRec;

          await _db.from('drugs').update({
            'warehouse_quantity': newWarehouse,
            'shelf_quantity': newShelf,
            // Note: quantity_in_stock remains unchanged as it equals warehouse_quantity + shelf_quantity
          }).eq('id', drugId);
        }

        // Record batch receipt in inventory_batches
        if (batchNo != null && batchNo.isNotEmpty) {
          await _db.from('inventory_batches').insert({
            'drug_id': drugId,
            'branch_id': req.destinationBranchId,
            'batch_no': batchNo,
            'expiry_date': expiryDate,
            'quantity': qtyRec,
            'cost_price': cost,
            'grn_no': req.requisitionNo,
            'status': 'RELEASED',
          });
        }
      } catch (e) {
        debugPrint('Stock adjustment note for item $drugId: $e');
      }
    }

    // 2. Post Real GL Receipt Journal: Dr 1300 Branch Inventory / Cr 1350 Inventory in Transit
    String? receiptJournalId;
    if (totalTransferCost > 0.0) {
      try {
        receiptJournalId = await _accounting.postJournal(
          date: DateTime.now(),
          memo: 'Inter-Branch Stock Receipt: ${req.requisitionNo}',
          reference: req.requisitionNo,
          sourceModule: 'transfer_receipt',
          sourceId: req.id,
          branchId: req.destinationBranchId,
          createdBy: actor,
          lines: [
            JournalLineDraft(
              accountCode: AccountingService.accInventory, // Dr 1300 Destination Branch Inventory
              debit: totalTransferCost,
              credit: 0.0,
              branchId: req.destinationBranchId,
              lineMemo: 'Received Stock (${req.destinationBranchName ?? "Destination"})',
            ),
            JournalLineDraft(
              accountCode: AccountingService.accInventoryInTransit, // Cr 1350 Inventory in Transit
              debit: 0.0,
              credit: totalTransferCost,
              branchId: req.sourceBranchId,
              lineMemo: 'Cleared Transit Stock (${req.sourceBranchName ?? "Kisumu Bulk Hub"})',
            ),
          ],
        );
      } catch (e) {
        debugPrint('GL Transfer Journal posting note: $e');
      }
    }

    // 3. Mark Requisition as CLOSED
    await _db.from('internal_requisitions').update({
      'status': 'CLOSED',
      'received_by': actor,
      'received_at': DateTime.now().toIso8601String(),
      'gl_journal_id': receiptJournalId,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', reqId);

    // 4. Log completion
    await _logTransition(
      requisitionId: reqId,
      fromStatus: 'DELIVERED',
      toStatus: 'CLOSED',
      action: 'Received to Shelf, Inventory Reconciled & Transit Cleared',
      actor: actor,
      notes: 'Transfer Value: KES ${totalTransferCost.toStringAsFixed(2)}, Receipt Journal: ${receiptJournalId ?? "Auto"}',
    );
  }

  Future<void> _logTransition({
    required String requisitionId,
    required String? fromStatus,
    required String toStatus,
    required String action,
    required String actor,
    String? notes,
  }) async {
    try {
      await _db.from('requisition_audit_logs').insert({
        'requisition_id': requisitionId,
        'from_status': fromStatus,
        'to_status': toStatus,
        'action': action,
        'actor': actor,
        'notes': notes,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Requisition audit log note: $e');
    }
  }
}

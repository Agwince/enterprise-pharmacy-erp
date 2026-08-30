class RequisitionItem {
  final String id;
  final String requisitionId;
  final String drugId;
  final String drugName;
  final int quantityRequested;
  int quantityPicked;
  int quantityReceived;
  final double unitCost;
  String? batchNo;
  DateTime? expiryDate;
  String? binLocation;

  RequisitionItem({
    required this.id,
    required this.requisitionId,
    required this.drugId,
    required this.drugName,
    required this.quantityRequested,
    this.quantityPicked = 0,
    this.quantityReceived = 0,
    this.unitCost = 0.0,
    this.batchNo,
    this.expiryDate,
    this.binLocation,
  });

  factory RequisitionItem.fromJson(Map<String, dynamic> json) {
    return RequisitionItem(
      id: json['id'] as String,
      requisitionId: json['requisition_id'] as String,
      drugId: json['drug_id'] as String,
      drugName: (json['drug_name'] ?? json['drugs']?['name'] ?? 'Medicine') as String,
      quantityRequested: (json['quantity_requested'] as num?)?.toInt() ?? 1,
      quantityPicked: (json['quantity_picked'] as num?)?.toInt() ?? 0,
      quantityReceived: (json['quantity_received'] as num?)?.toInt() ?? 0,
      unitCost: (json['unit_cost'] as num?)?.toDouble() ?? 0.0,
      batchNo: json['batch_no'] as String?,
      expiryDate: json['expiry_date'] != null ? DateTime.tryParse(json['expiry_date'].toString()) : null,
      binLocation: json['bin_location'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'requisition_id': requisitionId,
        'drug_id': drugId,
        'drug_name': drugName,
        'quantity_requested': quantityRequested,
        'quantity_picked': quantityPicked,
        'quantity_received': quantityReceived,
        'unit_cost': unitCost,
        'batch_no': batchNo,
        'expiry_date': expiryDate?.toIso8601String().substring(0, 10),
        'bin_location': binLocation,
      };
}

class RequisitionAuditLog {
  final String id;
  final String requisitionId;
  final String? fromStatus;
  final String toStatus;
  final String action;
  final String actor;
  final String? notes;
  final DateTime createdAt;

  RequisitionAuditLog({
    required this.id,
    required this.requisitionId,
    this.fromStatus,
    required this.toStatus,
    required this.action,
    required this.actor,
    this.notes,
    required this.createdAt,
  });

  factory RequisitionAuditLog.fromJson(Map<String, dynamic> json) {
    return RequisitionAuditLog(
      id: json['id'] as String,
      requisitionId: json['requisition_id'] as String,
      fromStatus: json['from_status'] as String?,
      toStatus: json['to_status'] as String,
      action: json['action'] as String,
      actor: json['actor'] as String,
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
    );
  }
}

class InternalRequisition {
  final String id;
  final String requisitionNo;
  final String? sourceBranchId;
  final String? sourceBranchName;
  final String? destinationBranchId;
  final String? destinationBranchName;
  final String requestedBy;
  String status;
  final String? notes;
  final int totalItemsCount;
  String? riderId;
  String? riderName;
  String? vehicleId;
  String? vehiclePlate;
  String? approvedBy;
  DateTime? approvedAt;
  String? pickedBy;
  DateTime? pickedAt;
  String? dispatchedBy;
  DateTime? dispatchedAt;
  String? deliveredBy;
  DateTime? deliveredAt;
  String? receivedBy;
  DateTime? receivedAt;
  String? glJournalId;
  final DateTime createdAt;
  final DateTime updatedAt;
  List<RequisitionItem> items;
  List<RequisitionAuditLog> auditLogs;

  InternalRequisition({
    required this.id,
    required this.requisitionNo,
    this.sourceBranchId,
    this.sourceBranchName,
    this.destinationBranchId,
    this.destinationBranchName,
    required this.requestedBy,
    required this.status,
    this.notes,
    this.totalItemsCount = 0,
    this.riderId,
    this.riderName,
    this.vehicleId,
    this.vehiclePlate,
    this.approvedBy,
    this.approvedAt,
    this.pickedBy,
    this.pickedAt,
    this.dispatchedBy,
    this.dispatchedAt,
    this.deliveredBy,
    this.deliveredAt,
    this.receivedBy,
    this.receivedAt,
    this.glJournalId,
    required this.createdAt,
    required this.updatedAt,
    this.items = const [],
    this.auditLogs = const [],
  });

  factory InternalRequisition.fromJson(Map<String, dynamic> json) {
    return InternalRequisition(
      id: json['id'] as String,
      requisitionNo: json['requisition_no'] as String,
      sourceBranchId: json['source_branch_id'] as String?,
      sourceBranchName: json['source_branch']?['name'] as String?,
      destinationBranchId: json['destination_branch_id'] as String?,
      destinationBranchName: json['destination_branch']?['name'] as String?,
      requestedBy: (json['requested_by'] ?? 'Branch Manager') as String,
      status: (json['status'] ?? 'DRAFT') as String,
      notes: json['notes'] as String?,
      totalItemsCount: (json['total_items_count'] as num?)?.toInt() ?? 0,
      riderId: json['rider_id'] as String?,
      riderName: json['rider_name'] as String?,
      vehicleId: json['vehicle_id'] as String?,
      vehiclePlate: json['vehicle_plate'] as String?,
      approvedBy: json['approved_by'] as String?,
      approvedAt: json['approved_at'] != null ? DateTime.tryParse(json['approved_at'].toString()) : null,
      pickedBy: json['picked_by'] as String?,
      pickedAt: json['picked_at'] != null ? DateTime.tryParse(json['picked_at'].toString()) : null,
      dispatchedBy: json['dispatched_by'] as String?,
      dispatchedAt: json['dispatched_at'] != null ? DateTime.tryParse(json['dispatched_at'].toString()) : null,
      deliveredBy: json['delivered_by'] as String?,
      deliveredAt: json['delivered_at'] != null ? DateTime.tryParse(json['delivered_at'].toString()) : null,
      receivedBy: json['received_by'] as String?,
      receivedAt: json['received_at'] != null ? DateTime.tryParse(json['received_at'].toString()) : null,
      glJournalId: json['gl_journal_id'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'].toString()) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'].toString()) : DateTime.now(),
      items: json['requisition_items'] != null
          ? (json['requisition_items'] as List)
              .map((i) => RequisitionItem.fromJson(Map<String, dynamic>.from(i as Map)))
              .toList()
          : [],
      auditLogs: json['requisition_audit_logs'] != null
          ? (json['requisition_audit_logs'] as List)
              .map((a) => RequisitionAuditLog.fromJson(Map<String, dynamic>.from(a as Map)))
              .toList()
          : [],
    );
  }
}

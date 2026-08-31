import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_admin.dart';

class BranchService {
  final SupabaseClient _db;

  BranchService({SupabaseClient? db})
      : _db = db ?? Supabase.instance.client;

  String? get _currentUserEmail => _db.auth.currentUser?.email;

  /// Fetch all branches
  Future<List<Map<String, dynamic>>> getBranches() async {
    final res = await _db.from('branches').select().order('code', ascending: true);
    return List<Map<String, dynamic>>.from(res as List);
  }

  /// Fetch active branches only
  Future<List<Map<String, dynamic>>> getActiveBranches() async {
    final res = await _db
        .from('branches')
        .select()
        .eq('is_active', true)
        .order('code', ascending: true);
    return List<Map<String, dynamic>>.from(res as List);
  }

  /// Get POS default branch or first active branch
  Future<Map<String, dynamic>?> getDefaultPosBranch() async {
    final defaultBranch = await _db
        .from('branches')
        .select()
        .eq('is_pos_default', true)
        .eq('is_active', true)
        .maybeSingle();

    if (defaultBranch != null) return defaultBranch;

    final firstActive = await _db
        .from('branches')
        .select()
        .eq('is_active', true)
        .order('code', ascending: true)
        .limit(1)
        .maybeSingle();

    return firstActive;
  }

  /// Set a branch as the POS default
  Future<void> setDefaultPosBranch(String branchId) async {
    await _db.from('branches').update({'is_pos_default': false}).neq('id', branchId);
    await _db.from('branches').update({'is_pos_default': true}).eq('id', branchId);
    
    // Log audit
    await _logAudit(
      branchId: branchId,
      action: 'SET_POS_DEFAULT',
      beforeData: {'is_pos_default': false},
      afterData: {'is_pos_default': true},
    );
  }

  /// Count dependencies before deleting
  Future<Map<String, int>> countBranchDependencies(String branchId) async {
    int txCount = 0;
    int staffCount = 0;
    int reqCount = 0;
    int payrollCount = 0;
    int stockCount = 0;
    int userCount = 0;

    try {
      final tx = await _db.from('transactions').select('id').eq('branch_id', branchId);
      txCount = (tx as List).length;
    } catch (_) {}

    try {
      final staff = await _db.from('staff').select('id').eq('branch_id', branchId);
      staffCount = (staff as List).length;
    } catch (_) {}

    try {
      final req1 = await _db.from('internal_requisitions').select('id').eq('requesting_branch_id', branchId);
      final req2 = await _db.from('internal_requisitions').select('id').eq('supplying_branch_id', branchId);
      reqCount = (req1 as List).length + (req2 as List).length;
    } catch (_) {}

    try {
      final payroll = await _db.from('payroll_runs').select('id').eq('branch_id', branchId);
      payrollCount = (payroll as List).length;
    } catch (_) {}

    try {
      final stock = await _db.from('inventory_batches').select('id').eq('branch_id', branchId);
      stockCount = (stock as List).length;
    } catch (_) {}

    try {
      final users = await _db.from('users').select('id').eq('branch_id', branchId);
      userCount = (users as List).length;
    } catch (_) {}

    final total = txCount + staffCount + reqCount + payrollCount + stockCount + userCount;

    return {
      'transactions': txCount,
      'staff': staffCount,
      'requisitions': reqCount,
      'payroll': payrollCount,
      'stock': stockCount,
      'users': userCount,
      'total': total,
    };
  }

  /// Create a new branch
  Future<Map<String, dynamic>> createBranch({
    required String code,
    required String name,
    String? address,
    String? phone,
    String? managerName,
    String? county,
    double? latitude,
    double? longitude,
    bool isActive = true,
    bool isPosDefault = false,
  }) async {
    final cleanCode = code.trim().toUpperCase();
    final cleanName = name.trim();

    if (cleanCode.isEmpty) throw Exception('Branch code is required.');
    if (cleanName.isEmpty) throw Exception('Branch name is required.');

    // Check duplicate code
    final existing = await _db.from('branches').select('id').eq('code', cleanCode).maybeSingle();
    if (existing != null) {
      throw Exception('Branch code $cleanCode already exists. Please choose a unique code.');
    }

    final payload = {
      'code': cleanCode,
      'name': cleanName,
      'address': address?.trim().isEmpty == true ? null : address?.trim(),
      'phone': phone?.trim().isEmpty == true ? null : phone?.trim(),
      'manager_name': managerName?.trim().isEmpty == true ? null : managerName?.trim(),
      'county': county?.trim().isEmpty == true ? null : county?.trim(),
      'latitude': latitude,
      'longitude': longitude,
      'is_active': isActive,
      'is_pos_default': isPosDefault,
      'updated_at': DateTime.now().toIso8601String(),
    };

    final inserted = await _db.from('branches').insert(payload).select().single();
    final branchId = inserted['id'].toString();

    // Verify persistence by re-reading
    final verified = await _db.from('branches').select().eq('id', branchId).single();

    // Audit log
    await _logAudit(
      branchId: branchId,
      branchCode: cleanCode,
      action: 'CREATED',
      beforeData: null,
      afterData: verified,
    );

    return verified;
  }

  /// Set branch latitude and longitude coordinates
  Future<Map<String, dynamic>> setBranchLocation(
    String id, {
    required double latitude,
    required double longitude,
  }) async {
    return await updateBranch(id, {
      'latitude': latitude,
      'longitude': longitude,
    });
  }

  /// Update branch details
  Future<Map<String, dynamic>> updateBranch(String id, Map<String, dynamic> updates) async {
    // Prevent ID / UUID modification
    updates.remove('id');

    if (updates.containsKey('code')) {
      final cleanCode = updates['code'].toString().trim().toUpperCase();
      if (cleanCode.isEmpty) throw Exception('Branch code cannot be empty.');
      final existing = await _db.from('branches').select('id').eq('code', cleanCode).neq('id', id).maybeSingle();
      if (existing != null) {
        throw Exception('Branch code  is already in use by another branch.');
      }
      updates['code'] = cleanCode;
    }

    if (updates.containsKey('name')) {
      final cleanName = updates['name'].toString().trim();
      if (cleanName.isEmpty) throw Exception('Branch name cannot be empty.');
      updates['name'] = cleanName;
    }

    updates['updated_at'] = DateTime.now().toIso8601String();

    // Fetch before-data for audit
    final before = await _db.from('branches').select().eq('id', id).single();

    await _db.from('branches').update(updates).eq('id', id);

    // Verify persistence by re-reading row
    final after = await _db.from('branches').select().eq('id', id).single();

    // Audit log
    String action = 'EDITED';
    if (updates.containsKey('is_active')) {
      action = updates['is_active'] == true ? 'REACTIVATED' : 'DEACTIVATED';
    }

    await _logAudit(
      branchId: id,
      branchCode: after['code']?.toString(),
      action: action,
      beforeData: before,
      afterData: after,
    );

    return after;
  }

  /// Deactivate branch (safe soft-delete)
  Future<Map<String, dynamic>> deactivateBranch(String id) async {
    return await updateBranch(id, {'is_active': false});
  }

  /// Reactivate branch
  Future<Map<String, dynamic>> reactivateBranch(String id) async {
    return await updateBranch(id, {'is_active': true});
  }

  /// Delete branch (permanently, only if 0 dependencies & not POS default)
  Future<void> deleteBranch(String id, String confirmationCode) async {
    final branch = await _db.from('branches').select().eq('id', id).maybeSingle();
    if (branch == null) throw Exception('Branch not found.');

    final expectedCode = (branch['code'] ?? '').toString().trim().toUpperCase();
    if (confirmationCode.trim().toUpperCase() != expectedCode) {
      throw Exception('Confirmation code  does not match branch code .');
    }

    if (branch['is_pos_default'] == true) {
      throw Exception('This is the point-of-sale default branch. Change the default in settings before deleting it.');
    }

    // Dependency check
    final deps = await countBranchDependencies(id);
    if ((deps['total'] ?? 0) > 0) {
      throw Exception(
        'Cannot delete branch  (): It has  linked records '
        '(Transactions: , Staff: , Requisitions: , '
        'Stock: , Users: ). Please deactivate the branch instead.',
      );
    }

    // Audit log
    await _logAudit(
      branchId: null,
      branchCode: expectedCode,
      action: 'DELETED',
      beforeData: branch,
      afterData: null,
    );

    // Perform delete
    await _db.from('branches').delete().eq('id', id);

    // Verify deletion
    final check = await _db.from('branches').select('id').eq('id', id).maybeSingle();
    if (check != null) {
      throw Exception('Failed to delete branch from database.');
    }
  }

  /// Fetch audit logs
  Future<List<Map<String, dynamic>>> getAuditLogs({String? branchId, String? branchCode}) async {
    var query = _db.from('branch_audit_logs').select();
    if (branchId != null) {
      query = query.eq('branch_id', branchId);
    }
    if (branchCode != null) {
      query = query.eq('branch_code', branchCode);
    }
    final res = await query.order('created_at', ascending: false).limit(100);
    return List<Map<String, dynamic>>.from(res as List);
  }

  Future<void> _logAudit({
    String? branchId,
    String? branchCode,
    required String action,
    Map<String, dynamic>? beforeData,
    Map<String, dynamic>? afterData,
  }) async {
    try {
      await _db.from('branch_audit_logs').insert({
        'branch_id': branchId,
        'branch_code': branchCode ?? beforeData?['code'] ?? afterData?['code'],
        'action': action,
        'performed_by': _currentUserEmail ?? AppAdmin.rootEmail,
        'before_data': beforeData,
        'after_data': afterData,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Audit log non-blocking fallback
    }
  }
}
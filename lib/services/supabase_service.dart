import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/branch.dart';
import '../models/drug.dart';
import 'cache_service.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;
  final CacheService _cache = CacheService();

  static const String drugSelectColumns =
      'id, name, generic_name, barcode, category, package_unit, target_shelf, price, cost, reorder_level, max_level, quantity_in_stock, thumb_url';

  /// Fetch all active pharmacy branches (15-min Hive cached)
  Future<List<Branch>> fetchBranches({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _cache.getCachedBranches();
      if (cached != null && cached.isNotEmpty) {
        return cached;
      }
    }

    try {
      final response = await _client.from('branches').select('id, name, code, is_active, created_at').order('name');
      final list = response as List<dynamic>;
      if (list.isNotEmpty) {
        final branches = list.map((json) => Branch.fromJson(json as Map<String, dynamic>)).toList();
        await _cache.saveBranches(branches);
        return branches;
      }
    } catch (e) {
      debugPrint('Fetch branches error (using offline fallback): $e');
      final fallback = _cache.getCachedBranches(ignoreTtl: true);
      if (fallback != null && fallback.isNotEmpty) return fallback;
    }
    return [];
  }

  /// High-speed single round trip branch revenue RPC (Replaces per-branch query loop)
  Future<List<Map<String, dynamic>>> fetchBranchRevenue() async {
    try {
      final response = await _client.rpc('mc_branch_revenue');
      if (response != null && response is List) {
        return List<Map<String, dynamic>>.from(response.map((e) => Map<String, dynamic>.from(e as Map)));
      }
    } catch (e) {
      debugPrint('RPC mc_branch_revenue fallback to single query: $e');
    }

    // Fallback: single round-trip aggregation query without N+1 loops
    try {
      final branches = await fetchBranches();
      final txRes = await _client
          .from('transactions')
          .select('branch_id, total_amount')
          .eq('transaction_type', 'sale');
      
      final txList = txRes as List<dynamic>;
      final Map<String, double> branchSums = {};
      for (final tx in txList) {
        final bId = tx['branch_id']?.toString() ?? '';
        final amt = (tx['total_amount'] as num?)?.toDouble() ?? 0.0;
        branchSums[bId] = (branchSums[bId] ?? 0.0) + amt;
      }

      return branches.map((b) => {
        'branch_id': b.id,
        'branch_name': b.name,
        'code': b.code,
        'revenue': branchSums[b.id] ?? 0.0,
      }).toList();
    } catch (e) {
      debugPrint('Branch revenue fallback error: $e');
      return [];
    }
  }

  /// High-speed CEO & Branch Dashboard Header KPIs in a single round-trip
  Future<Map<String, dynamic>> fetchDashboardKpis({String? branchId}) async {
    try {
      final res = await _client.rpc(
        'mc_dashboard_kpis',
        params: {'p_branch_id': branchId},
      );
      if (res != null) {
        return Map<String, dynamic>.from(res as Map);
      }
    } catch (e) {
      debugPrint('RPC mc_dashboard_kpis fallback: $e');
    }

    // Fallback: fast bounded queries
    try {
      var txQuery = _client.from('transactions').select('total_amount').eq('transaction_type', 'sale');
      if (branchId != null) txQuery = txQuery.eq('branch_id', branchId);
      final sales = await txQuery;

      double totalRev = 0.0;
      for (final s in (sales as List<dynamic>)) {
        totalRev += (s['total_amount'] as num?)?.toDouble() ?? 0.0;
      }

      return {
        'total_revenue': totalRev,
        'today_revenue': 0.0,
        'total_transactions': sales.length,
        'low_stock_count': 0,
        'pending_pos': 0,
        'unposted_gl_count': 0,
      };
    } catch (e) {
      return {'total_revenue': 0.0, 'total_transactions': 0};
    }
  }

  /// Fetch paginated and server-side searched drugs (15-min Hive cached)
  Future<List<Drug>> fetchDrugs({
    int limit = 50,
    int offset = 0,
    String? search,
    bool forceRefresh = false,
  }) async {
    final queryText = search?.trim() ?? '';

    // If offline or fast cached startup without search filter
    if (!forceRefresh && queryText.isEmpty && offset == 0) {
      final cached = _cache.getCachedDrugs();
      if (cached != null && cached.isNotEmpty) {
        return cached.take(limit).toList();
      }
    }

    try {
      var query = _client
          .from('drugs')
          .select(drugSelectColumns);

      if (queryText.isNotEmpty) {
        query = query.or('name.ilike.%$queryText%,generic_name.ilike.%$queryText%,barcode.ilike.%$queryText%');
      }

      final response = await query
          .order('name')
          .range(offset, offset + limit - 1);

      final list = response as List<dynamic>;
      final drugs = list.map((json) => Drug.fromJson(json as Map<String, dynamic>)).toList();

      // If fetching initial page without search, save to Hive cache
      if (offset == 0 && queryText.isEmpty && drugs.isNotEmpty) {
        _cache.saveDrugs(drugs);
      }

      return drugs;
    } catch (e) {
      debugPrint('Fetch drugs error (using offline local search): $e');
      return _cache.searchLocalDrugs(queryText).skip(offset).take(limit).toList();
    }
  }

  /// RPC Algorithm 1: ABC Analysis (30-day sales velocity)
  Future<List<Map<String, dynamic>>> getAbcClassification({String? branchId}) async {
    try {
      final response = await _client.rpc(
        'get_abc_classification',
        params: {'p_branch_id': branchId, 'p_days': 30},
      );
      final list = response as List<dynamic>;
      if (list.isNotEmpty) {
        return list.map((item) => Map<String, dynamic>.from(item as Map)).toList();
      }
    } catch (e) {
      debugPrint('RPC get_abc_classification fallback: $e');
    }

    return [];
  }

  /// RPC Algorithm 2: Smart Replenishment Auto-Draft PO
  Future<Map<String, dynamic>> autoDraftPurchaseOrders({String? branchId}) async {
    try {
      final response = await _client.rpc(
        'auto_draft_purchase_orders',
        params: {'p_branch_id': branchId},
      );
      if (response != null) {
        return Map<String, dynamic>.from(response as Map);
      }
    } catch (e) {
      debugPrint('RPC auto_draft_purchase_orders fallback: $e');
    }

    return {
      'success': false,
      'message': 'Failed to auto-draft purchase order.'
    };
  }
}

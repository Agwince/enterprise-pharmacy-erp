import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/drug.dart';
import '../models/branch.dart';

class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  static const String _cacheBoxName = 'mediocare_app_cache';
  static const String _keyDrugs = 'cache_drugs_catalog';
  static const String _keyDrugsTimestamp = 'cache_drugs_ts';
  static const String _keyBranches = 'cache_branches';
  static const String _keyBranchesTimestamp = 'cache_branches_ts';

  static const Duration defaultTtl = Duration(minutes: 15);

  Box? _box;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      await Hive.initFlutter();
      _box = await Hive.openBox(_cacheBoxName);
      _initialized = true;
      debugPrint('📦 CacheService initialized successfully with Hive.');
    } catch (e) {
      debugPrint('CacheService Hive initialization note: $e');
    }
  }

  bool _isExpired(String tsKey, Duration ttl) {
    if (_box == null) return true;
    final int? ts = _box!.get(tsKey) as int?;
    if (ts == null) return true;
    final cachedTime = DateTime.fromMillisecondsSinceEpoch(ts);
    return DateTime.now().difference(cachedTime) > ttl;
  }

  // ===========================================================================
  // DRUGS CACHE
  // ===========================================================================
  List<Drug>? getCachedDrugs({bool ignoreTtl = false}) {
    if (_box == null) return null;
    if (!ignoreTtl && _isExpired(_keyDrugsTimestamp, defaultTtl)) return null;

    final raw = _box!.get(_keyDrugs);
    if (raw == null) return null;

    try {
      final List<dynamic> list = raw is String ? jsonDecode(raw) : (raw as List);
      return list.map((item) => Drug.fromJson(Map<String, dynamic>.from(item as Map))).toList();
    } catch (e) {
      debugPrint('Failed to decode cached drugs: $e');
      return null;
    }
  }

  Future<void> saveDrugs(List<Drug> drugs) async {
    if (_box == null) return;
    try {
      final jsonList = drugs.map((d) => d.toJson()).toList();
      await _box!.put(_keyDrugs, jsonList);
      await _box!.put(_keyDrugsTimestamp, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('Failed to save drugs to Hive cache: $e');
    }
  }

  // ===========================================================================
  // BRANCHES CACHE
  // ===========================================================================
  List<Branch>? getCachedBranches({bool ignoreTtl = false}) {
    if (_box == null) return null;
    if (!ignoreTtl && _isExpired(_keyBranchesTimestamp, defaultTtl)) return null;

    final raw = _box!.get(_keyBranches);
    if (raw == null) return null;

    try {
      final List<dynamic> list = raw is String ? jsonDecode(raw) : (raw as List);
      return list.map((item) => Branch.fromJson(Map<String, dynamic>.from(item as Map))).toList();
    } catch (e) {
      debugPrint('Failed to decode cached branches: $e');
      return null;
    }
  }

  Future<void> saveBranches(List<Branch> branches) async {
    if (_box == null) return;
    try {
      final jsonList = branches.map((b) => b.toJson()).toList();
      await _box!.put(_keyBranches, jsonList);
      await _box!.put(_keyBranchesTimestamp, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('Failed to save branches to Hive cache: $e');
    }
  }

  /// Search offline catalog locally
  List<Drug> searchLocalDrugs(String query) {
    final allDrugs = getCachedDrugs(ignoreTtl: true) ?? [];
    if (query.trim().isEmpty) return allDrugs;

    final q = query.toLowerCase().trim();
    return allDrugs.where((d) {
      final name = d.name.toLowerCase();
      final gen = (d.genericName ?? '').toLowerCase();
      final sku = d.sku.toLowerCase();
      final cat = d.category.toLowerCase();
      return name.contains(q) || gen.contains(q) || sku.contains(q) || cat.contains(q);
    }).toList();
  }
}

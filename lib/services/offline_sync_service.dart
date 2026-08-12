import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/transaction.dart';

class OfflineSyncService extends ChangeNotifier {
  static final OfflineSyncService _instance = OfflineSyncService._internal();
  factory OfflineSyncService() => _instance;
  OfflineSyncService._internal();

  static const String _boxName = 'pending_transactions_box';
  Box<Map>? _pendingBox;
  bool _isOnline = true;
  bool _isSyncing = false;

  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;
  int get pendingCount => _pendingBox?.length ?? 0;

  Future<void> initialize() async {
    try {
      await Hive.initFlutter();
      _pendingBox = await Hive.openBox<Map>(_boxName);
      notifyListeners();
    } catch (e) {
      debugPrint('Hive init warning: $e');
    }
  }

  void setOnlineStatus(bool status) {
    if (_isOnline != status) {
      _isOnline = status;
      notifyListeners();
      if (_isOnline && pendingCount > 0) {
        syncPendingTransactions();
      }
    }
  }

  /// Store a transaction locally during network outage
  Future<void> queueTransaction(TransactionRecord tx) async {
    final key = tx.id;
    final map = tx.toJson();
    map['queued_at'] = DateTime.now().toIso8601String();
    
    if (_pendingBox != null) {
      await _pendingBox!.put(key, map);
    }
    notifyListeners();

    // If online, try syncing immediately
    if (_isOnline) {
      await syncPendingTransactions();
    }
  }

  /// Flush all queued pending transactions to Supabase Cloud
  Future<int> syncPendingTransactions() async {
    if (_pendingBox == null || _pendingBox!.isEmpty || _isSyncing) {
      return 0;
    }

    _isSyncing = true;
    notifyListeners();
    int syncedCount = 0;

    final client = Supabase.instance.client;
    final keysToSync = List<dynamic>.from(_pendingBox!.keys);

    for (final key in keysToSync) {
      final rawMap = _pendingBox!.get(key);
      if (rawMap == null) continue;

      final Map<String, dynamic> txMap = Map<String, dynamic>.from(rawMap);
      txMap.remove('queued_at'); // Remove local metadata

      try {
        await client.from('transactions').insert(txMap);
        await _pendingBox!.delete(key);
        syncedCount++;
      } catch (e) {
        debugPrint('Sync failed for item $key: $e');
        // Stop batch if network fails
        break;
      }
    }

    _isSyncing = false;
    notifyListeners();
    return syncedCount;
  }
}

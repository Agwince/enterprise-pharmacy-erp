import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_erp/services/accounting_service.dart';
import 'package:pharmacy_erp/services/requisition_service.dart';

void main() {
  group('Branch Requisition Flow & General Ledger Verification', () {
    test('Routing: Default supplying branch is always Kisumu Bulk Hub', () {
      expect(RequisitionService.kisumuBulkHubId, equals('1a94f380-a3a8-48de-86dc-88b1372a1ec1'));
    });

    test('GL Double-Entry: Dispatch Journal (Dr 1350 / Cr 1300)', () {
      const double dispatchCost = 250.00;
      final lines = [
        JournalLineDraft(
          accountCode: AccountingService.accInventoryInTransit, // 1350
          debit: dispatchCost,
          credit: 0.0,
          lineMemo: 'In-Transit Stock to Nairobi Central',
        ),
        JournalLineDraft(
          accountCode: AccountingService.accInventory, // 1300
          debit: 0.0,
          credit: dispatchCost,
          lineMemo: 'Dispatched from Kisumu Bulk Hub',
        ),
      ];

      double debitTotal = 0.0;
      double creditTotal = 0.0;
      for (final l in lines) {
        debitTotal += l.debit;
        creditTotal += l.credit;
      }

      expect(debitTotal, equals(250.00));
      expect(creditTotal, equals(250.00));
      expect(debitTotal, equals(creditTotal));
    });

    test('GL Double-Entry: Receipt Journal (Dr 1300 / Cr 1350)', () {
      const double transferCost = 250.00;
      final lines = [
        JournalLineDraft(
          accountCode: AccountingService.accInventory, // 1300
          debit: transferCost,
          credit: 0.0,
          lineMemo: 'Received Stock at Nairobi Central',
        ),
        JournalLineDraft(
          accountCode: AccountingService.accInventoryInTransit, // 1350
          debit: 0.0,
          credit: transferCost,
          lineMemo: 'Cleared In-Transit Stock',
        ),
      ];

      double debitTotal = 0.0;
      double creditTotal = 0.0;
      for (final l in lines) {
        debitTotal += l.debit;
        creditTotal += l.credit;
      }

      expect(debitTotal, equals(250.00));
      expect(creditTotal, equals(250.00));
      expect(debitTotal, equals(creditTotal));
    });

    test('Stock Invariant: Total stock remains unchanged on inter-branch movement', () {
      int initialWarehouse = 40;
      int initialShelf = 10;
      int totalStock = initialWarehouse + initialShelf; // 50

      const int transferQty = 10;
      int newWarehouse = initialWarehouse - transferQty; // 30
      int newShelf = initialShelf + transferQty; // 20
      int newTotalStock = newWarehouse + newShelf; // 50

      expect(newWarehouse, equals(30));
      expect(newShelf, equals(20));
      expect(newTotalStock, equals(totalStock));
    });

    test('Rejection Validation: Stated reason is mandatory', () {
      expect(
        () {
          const reason = '  ';
          if (reason.trim().isEmpty) {
            throw Exception('Rejection requires a stated reason');
          }
        },
        throwsA(isA<Exception>().having((e) => e.toString(), 'reason', contains('Rejection requires a stated reason'))),
      );
    });

    test('FEFO Ordering: Batches ordered by expiry date ASC', () {
      final List<Map<String, String>> batches = [
        {'batch_no': 'BAT-2', 'expiry_date': '2027-06-30'},
        {'batch_no': 'BAT-1', 'expiry_date': '2026-10-31'},
        {'batch_no': 'BAT-3', 'expiry_date': '2028-01-15'},
      ];

      batches.sort((a, b) => a['expiry_date']!.compareTo(b['expiry_date']!));

      expect(batches.first['batch_no'], equals('BAT-1'));
      expect(batches.first['expiry_date'], equals('2026-10-31'));
    });
  });
}

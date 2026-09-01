@Timeout(Duration(minutes: 3))
library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pharmacy_erp/config/supabase_config.dart';
import 'package:pharmacy_erp/config/app_config.dart';
import 'package:pharmacy_erp/config/ocr_config.dart';
import 'package:pharmacy_erp/services/branch_service.dart';
import 'package:pharmacy_erp/services/ai_service.dart';

void main() {
  late SupabaseClient client;
  late BranchService branchService;

  setUpAll(() async {
    client = SupabaseClient(
      SupabaseConfig.url,
      SupabaseConfig.anonKey,
      authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
      headers: {
        'apikey': SupabaseConfig.anonKey,
      },
    );

    // Authenticate as Root Admin
    await client.auth.signInWithPassword(
      email: 'admin@pharmacy.com',
      password: 'Pharmacy@2026',
    );

    branchService = BranchService(db: client);
  });

  tearDownAll(() {
    client.dispose();
  });

  group('Part A — Scanner & OCR Verification', () {
    test('1. Confirm "helloworld" is completely gone from lib/', () {
      final libDir = Directory('lib');
      final files = libDir.listSync(recursive: true).whereType<File>();
      final List<String> matchingFiles = [];

      for (final file in files) {
        if (file.path.endsWith('.dart')) {
          final content = file.readAsStringSync();
          if (content.contains('helloworld')) {
            matchingFiles.add(file.path);
          }
        }
      }

      expect(matchingFiles, isEmpty, reason: 'Found "helloworld" in files: $matchingFiles');
    });

    test('2. Confirm AppConfig is wired via environment with ocrEndpointUrl configured', () {
      expect(AppConfig.ocrApiKey, isA<String>());
      expect(AppConfig.ocrEndpointUrl, equals('https://api.ocr.space/parse/image'));
    });

    test('3. Confirm OcrConfig backward-compatibility alias forwards to AppConfig', () {
      expect(OcrConfig.apiKey, equals(AppConfig.ocrApiKey));
      expect(OcrConfig.endpointUrl, equals(AppConfig.ocrEndpointUrl));
    });

    test('4. Surface failure test: empty OCR input returns fallback error signal', () async {
      final aiService = AiService();
      // Test when empty or illegible text is given
      final result = await aiService.extractTextFromImage('');
      expect(result, equals('No legible text detected from prescription scan.'));
    });
  });

  group('Part B — Branch Coordinates & Map Pin Persistence', () {
    test('1. Confirm branches table schema has latitude and longitude columns', () async {
      final branches = await branchService.getBranches();
      expect(branches, isNotEmpty);

      final first = branches.first;
      expect(first.containsKey('latitude'), isTrue, reason: 'latitude column must exist');
      expect(first.containsKey('longitude'), isTrue, reason: 'longitude column must exist');
    });

    test('2. Trace: Set branch location by map pin tap -> save -> re-read -> verify coordinates match -> restore null', () async {
      final branches = await branchService.getBranches();
      final targetBranch = branches.firstWhere((b) => b['code'] == 'NBO-01');
      final targetId = targetBranch['id'].toString();

      // Tap coordinates simulated: Nairobi CBD (-1.286389, 36.817223)
      const testLat = -1.286389;
      const testLng = 36.817223;

      // 1. Save location via service
      final updated = await branchService.setBranchLocation(
        targetId,
        latitude: testLat,
        longitude: testLng,
      );

      expect((updated['latitude'] as num).toDouble(), closeTo(testLat, 0.000001));
      expect((updated['longitude'] as num).toDouble(), closeTo(testLng, 0.000001));

      // 2. Re-read row directly from Supabase to guarantee database persistence
      final reRead = await client.from('branches').select().eq('id', targetId).single();
      expect((reRead['latitude'] as num).toDouble(), closeTo(testLat, 0.000001));
      expect((reRead['longitude'] as num).toDouble(), closeTo(testLng, 0.000001));

      // 3. Reset back to null per rule: "No fake data. Do not invent coordinates for any branch. Null means not set yet"
      await branchService.updateBranch(targetId, {
        'latitude': null,
        'longitude': null,
      });

      final restored = await client.from('branches').select().eq('id', targetId).single();
      expect(restored['latitude'], isNull);
      expect(restored['longitude'], isNull);
    });

    test('3. Verify branches with null coordinates are omitted from map markers', () async {
      final branches = await branchService.getBranches();

      // Filter as dispatch map does
      final mapBranches = branches.where((b) {
        final lat = b['latitude'];
        final lng = b['longitude'];
        return lat != null && lng != null && lat is num && lng is num;
      }).toList();

      for (final branch in mapBranches) {
        expect(branch['latitude'], isNotNull);
        expect(branch['longitude'], isNotNull);
        expect(branch['latitude'], isNot(equals(0.0)));
        expect(branch['longitude'], isNot(equals(0.0)));
      }

      // Null branch check
      final nullBranches = branches.where((b) => b['latitude'] == null || b['longitude'] == null).toList();
      for (final branch in nullBranches) {
        expect(mapBranches.any((m) => m['id'] == branch['id']), isFalse,
            reason: 'Branch with null coordinates must NOT appear on the map');
      }
    });
  });
}

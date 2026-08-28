import 'dart:convert';
import 'dart:io';
import 'lib/models/drug.dart';
import 'lib/config/supabase_config.dart';

void main() async {
  var url = Uri.parse('https://sodxtvyusndehtycgino.supabase.co/rest/v1/drugs?select=*');
  var request = await HttpClient().getUrl(url);
  request.headers.add('apikey', SupabaseConfig.anonKey);
  request.headers.add('Authorization', 'Bearer ${SupabaseConfig.anonKey}');
  var response = await request.close();
  var responseBody = await response.transform(utf8.decoder).join();
  var jsonList = jsonDecode(responseBody) as List<dynamic>;
  
  print('Fetched ${jsonList.length} drugs.');
  
  List<Drug> drugs = [];
  for (var json in jsonList) {
    try {
      drugs.add(Drug.fromJson(json as Map<String, dynamic>));
    } catch (e) {
      // ignore
    }
  }

  print('Parsed ${drugs.length} drugs. Now testing map...');
  
  try {
    final List<Map<String, dynamic>> items = drugs.map((drug) {
        final isFractional = drug.name.contains('0.10') || drug.name.contains('10ML') || drug.name.contains('SUSP');
        final double pickQty = isFractional ? 0.10 : 1.0;
        final String innerUnitType = (drug.toJson()['inner_unit_type'] as String?) ??
            (drug.name.toUpperCase().contains('SUSP') || drug.name.toUpperCase().contains('LIQ') || drug.name.toUpperCase().contains('SYRUP')
                ? 'Bottle'
                : 'Strip/Blister');

        return {
          'id': drug.id,
          'sku': drug.sku,
          'name': drug.name,
          'pick_quantity': pickQty,
          'inner_unit_type': innerUnitType,
          'unit_label': isFractional
              ? 'Pick: 0.10 (1 Loose $innerUnitType)'
              : 'Pick: 1.0 (Full Sealed Box)',
          'location': '📍 ${drug.binLocation}',
          'box_image_url': drug.imageUrl,
          'loose_unit_image_url': drug.innerUnitImageUrl,
          'checked': false,
          'quantity_picked': 1,
          'quantity_in_stock': drug.quantityInStock,
          'min_threshold': drug.minThreshold,
        };
      }).toList();
      print('Map succeeded! Items: ${items.length}');
  } catch (e, st) {
      print('Error during map: $e');
      print(st);
  }
}

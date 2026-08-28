import 'dart:convert';
import 'dart:io';
import 'lib/config/supabase_config.dart';

void main() async {
  var url = Uri.parse('https://sodxtvyusndehtycgino.supabase.co/rest/v1/drugs?select=*&order=target_shelf.asc');
  var request = await HttpClient().getUrl(url);
  request.headers.add('apikey', SupabaseConfig.anonKey);
  request.headers.add('Authorization', 'Bearer ${SupabaseConfig.anonKey}');
  var response = await request.close();
  var responseBody = await response.transform(utf8.decoder).join();
  
  if (response.statusCode != 200) {
    print('Error: ${response.statusCode}');
    print(responseBody);
  } else {
    var jsonList = jsonDecode(responseBody) as List<dynamic>;
    print('Fetched ${jsonList.length} drugs with order by target_shelf.');
  }
}

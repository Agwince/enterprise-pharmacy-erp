import 'dart:convert';
import 'dart:io';
import 'lib/config/supabase_config.dart';

void main() async {
  var url = Uri.parse('https://sodxtvyusndehtycgino.supabase.co/rest/v1/drugs?select=*&limit=1');
  var request = await HttpClient().getUrl(url);
  request.headers.add('apikey', SupabaseConfig.anonKey);
  request.headers.add('Authorization', 'Bearer ${SupabaseConfig.anonKey}');
  var response = await request.close();
  var responseBody = await response.transform(utf8.decoder).join();
  var jsonList = jsonDecode(responseBody) as List<dynamic>;
  
  if (jsonList.isNotEmpty) {
    print(jsonList[0].keys.toList());
  } else {
    print('No drugs found');
  }
}

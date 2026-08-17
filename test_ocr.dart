import 'dart:convert';
import 'dart:io';

void main() async {
  print('Testing OCR...');
  var request = HttpClient().postUrl(Uri.parse('https://api.ocr.space/parse/image'));
  // too complex to do multipart with dart:io HttpClient manually.
}

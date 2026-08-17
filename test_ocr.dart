
import 'dart:convert';
import 'dart:io';

void main() async {
  print('Testing OCR...');
  var request = http.MultipartRequest('POST', Uri.parse('https://api.ocr.space/parse/image'));
  // wait, I don't have http in this script, I'll use dart:io HttpClient
}


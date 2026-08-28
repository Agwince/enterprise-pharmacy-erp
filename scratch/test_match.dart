void main() {
  List<String> allDrugNames = [
    "KIFARU 100MG 4'S",
    "AMOXICILLIN 500MG",
    "ACECLOFENAC 100MG 30'S"
  ];
  
  String rawOcrText = "KIFARU 100MG 4'S 2.00";
  List<String> extractedWords = rawOcrText.split(' ');
  List<String> foundTerms = [];

  for (String dbName in allDrugNames) {
    final String normalizedDbName = dbName.replaceAll(RegExp(r'\s+'), '');
    final String normalizedOcrText = rawOcrText.replaceAll(RegExp(r'\s+'), '');

    bool isMatch = false;

    if (normalizedOcrText.contains(normalizedDbName)) {
       isMatch = true;
    } else {
       List<String> dbWords = dbName.split(RegExp(r'\s+')).where((w) => w.length > 2).toList();
       if (dbWords.length >= 2) {
         if (rawOcrText.contains(dbWords[0]) && rawOcrText.contains(dbWords[1])) {
           isMatch = true;
         }
       } else if (dbWords.isNotEmpty) {
         if (rawOcrText.contains(dbWords[0]) && dbWords[0].length > 5) {
           isMatch = true;
         }
       }
    }

    if (isMatch) {
      foundTerms.add(dbName);
    }
  }

  print("Found terms: $foundTerms");
}

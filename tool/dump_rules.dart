import 'dart:io';

void main() {
  File(
    'tool/rules.txt',
  ).writeAsStringSync(File('firestore.rules').readAsStringSync());
}

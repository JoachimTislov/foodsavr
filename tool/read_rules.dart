// ignore_for_file: avoid_print
import 'dart:io';

import 'deploy/auth.dart';

Future<void> main() async {
  final rulesPath = await getRulesPath();
  print(File(rulesPath).readAsStringSync());
}

import 'package:flutter/services.dart';

class Config {
  // isDevelopment is default when appFlavor isn't set
  static const bool isDevelopment = appFlavor == null;
  static const String? environment = isDevelopment ? 'development' : appFlavor;
  static const String testUserEmail = 'bob@gmail.com';
  static const String testUserPassword = 'password123';
}

import 'package:flutter/services.dart';

class Config {
  // isDevelopment is default when appFlavor isn't set
  static const isDevelopment = appFlavor == null;
  static const environment = isDevelopment ? 'development' : appFlavor;
  static const testUserEmail = 'bob@gmail.com';
  static const testUserPassword = 'password123';
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../../interfaces/i_auth_service.dart';
import '../../service_locator.dart';
import '../../services/auth_controller.dart';

final authControllerProvider = ChangeNotifierProvider<AuthController>(
  (ref) => AuthController(getIt<IAuthService>(), getIt<Logger>()),
);

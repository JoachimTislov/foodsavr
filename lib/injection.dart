import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import 'injection.config.dart';

final getIt = GetIt.instance;

@InjectableInit()
void configureDependencies() {
  // Allow reassignment to handle hot reload and full restart gracefully
  getIt.allowReassignment = true;
  getIt.init();
}

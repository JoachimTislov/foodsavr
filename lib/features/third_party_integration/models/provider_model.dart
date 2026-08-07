import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:foodsavr/utils/config.dart';

enum Provider {
  coop('Coop Medlem'),
  rema('Rema'),
  trumf('Trumf');

  const Provider(this._name);

  final String _name;

  @override
  toString() {
    return _name;
  }

  String logoPath() {
    return 'assets/logos/$name.svg';
  }

  /// checks if provider is configured for the given env
  bool isSupported() {
    return Config.isDevelopment ||
        (Config.isProduction &&
            dotenv.env['${name.toUpperCase()}_IS_SUPPORTED'] != null);
  }
}

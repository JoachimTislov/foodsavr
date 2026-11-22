import 'behavior.dart';
import 'environment.dart';
import 'identity.dart';
import 'level.dart';
import 'trigger.dart';

/// A FoodSavr deployment instance: who it is, which capabilities the app
/// needs, the shared ladder of deployment levels, the triggers that
/// recommend moving along it, and the environments (flavors) that each sit
/// at one level of that ladder.
///
/// Shape: specs/source-of-truth/schemas/deployment-instance.schema.json.
/// Manifest: deploy/instance.yaml.
class DeploymentInstance {
  const DeploymentInstance({
    required this.version,
    required this.identity,
    required this.capabilities,
    required this.levels,
    required this.triggers,
    required this.behavior,
    required this.environments,
  });

  final int version;
  final Identity identity;
  final List<String> capabilities;
  final List<Level> levels;
  final List<Trigger> triggers;
  final Behavior behavior;
  final Map<String, Environment> environments;

  /// Index of the level called [name] in the ladder, or -1.
  int indexOf(String name) => levels.indexWhere((l) => l.name == name);

  Level? levelNamed(String name) {
    final i = indexOf(name);
    return i < 0 ? null : levels[i];
  }
}

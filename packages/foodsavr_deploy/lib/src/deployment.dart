import 'model/behavior.dart';
import 'model/deployment_instance.dart';
import 'model/environment.dart';
import 'model/identity.dart';
import 'model/level.dart';
import 'model/trigger.dart';

/// One environment of an instance with its overrides applied: flavor ×
/// level. Everything that plans, polls or emits config works on this view.
class Deployment {
  Deployment(this.instance, this.environment)
    : triggers = _resolveTriggers(instance.triggers, environment.triggers),
      behavior = _resolveBehavior(instance.behavior, environment.behavior);

  /// The view for environment [name]; throws [ArgumentError] if undeclared.
  factory Deployment.of(DeploymentInstance i, String name) {
    final env = i.environments[name];
    if (env == null) {
      throw ArgumentError.value(
        name,
        'env',
        'not declared (have: ${i.environments.keys.join(', ')})',
      );
    }
    return Deployment(i, env);
  }

  final DeploymentInstance instance;
  final Environment environment;

  /// Shared triggers with this environment's overrides; disabled ones
  /// removed.
  final List<Trigger> triggers;
  final Behavior behavior;

  String get flavor => environment.name;
  Identity get identity => instance.identity;
  FirebaseIdentity? get firebase => environment.firebase;
  List<Level> get levels => instance.levels;
  List<String> get capabilities => instance.capabilities;
  String get currentLevel => environment.currentLevel;

  int indexOf(String name) => instance.indexOf(name);
  Level? levelNamed(String name) => instance.levelNamed(name);

  Level get current => levels[indexOf(currentLevel)];

  /// Hosting site of release [channel]; the default site without one.
  String? siteFor(String? channel) =>
      (channel == null ? null : environment.channels[channel]) ??
      firebase?.siteId;

  /// Hosting sites the channels add beside the project's default site.
  List<String> get channelSites {
    final fb = firebase;
    return [
      for (final site in {...environment.channels.values.nonNulls})
        if (fb == null || (site != fb.projectId && site != fb.siteId)) site,
    ];
  }

  Level? get next {
    final i = indexOf(currentLevel);
    return i >= 0 && i + 1 < levels.length ? levels[i + 1] : null;
  }

  Level? get previous {
    final i = indexOf(currentLevel);
    return i > 0 ? levels[i - 1] : null;
  }

  /// Triggers active on [level]: it binds their capability to their binding.
  List<Trigger> activeTriggers(Level level) =>
      triggers.where((t) => t.appliesTo(level)).toList();
}

List<Trigger> _resolveTriggers(
  List<Trigger> shared,
  Map<String, TriggerOverride> overrides,
) => [
  for (final t in shared)
    if (overrides[t.name]?.enabled ?? true)
      Trigger(
        name: t.name,
        capability: t.capability,
        binding: t.binding,
        scaler: t.scaler,
        limit: t.limit,
        warn: overrides[t.name]?.warn ?? t.warn,
        promote: overrides[t.name]?.promote ?? t.promote,
        demote: overrides[t.name]?.demote ?? t.demote,
        description: t.description,
      ),
];

Behavior _resolveBehavior(Behavior b, BehaviorOverride? o) => o == null
    ? b
    : Behavior(
        pollingInterval: o.pollingInterval ?? b.pollingInterval,
        stabilizationPolls: o.stabilizationPolls ?? b.stabilizationPolls,
        minDwell: o.minDwell ?? b.minDwell,
        mode: o.mode ?? b.mode,
        fallback: b.fallback,
      );

import 'deployment.dart';
import 'model/behavior.dart';
import 'model/deployment_instance.dart';
import 'model/environment.dart';
import 'model/level.dart';
import 'model/trigger.dart';

/// Scaler types `levels poll` knows (see scalers.dart).
const scalerTypes = {
  'firebaseAuthUsers',
  'firestoreDailyOps',
  'hostingStorage',
  'deployGuard',
  'file',
};

/// Capabilities whose move needs no user-data migration.
const statelessCapabilities = {'hosting', 'appCheck'};

/// Least disruptive class that covers moving [from] → [to], derived from the
/// binding diff: auth moves dominate data moves, which dominate redeploys.
MigrationClass transitionClass(Level from, Level to) {
  var c = from.provider == to.provider
      ? MigrationClass.inPlace
      : MigrationClass.redeploy;
  for (final cap in {...from.bindings.keys, ...to.bindings.keys}) {
    if (from.bindings[cap] == to.bindings[cap]) continue;
    c = c.max(
      cap == 'auth'
          ? MigrationClass.authMove
          : statelessCapabilities.contains(cap)
          ? MigrationClass.redeploy
          : MigrationClass.dataMove,
    );
  }
  return c;
}

class ValidationReport {
  final errors = <String>[];
  final warnings = <String>[];

  bool get ok => errors.isEmpty;
}

/// Semantic checks on a structurally valid manifest, for the shared ladder
/// and every environment.
ValidationReport validate(DeploymentInstance i) {
  final r = ValidationReport();
  void err(String m) => r.errors.add(m);

  if (i.version != 1) err('version: only version 1 is supported');
  if (!RegExp(r'^[\w.-]+/[\w.-]+$').hasMatch(i.identity.githubRepository)) {
    err('identity.githubRepository: expected owner/repo');
  }
  if (i.capabilities.toSet().length != i.capabilities.length) {
    err('capabilities: duplicates');
  }
  _ladder(i, err);
  _triggers(i, err);

  if (!i.environments.containsKey('production')) {
    err('environments: production is required');
  }
  for (final env in i.environments.values) {
    _environment(i, env, r);
  }
  _uniqueIdentities(i, err);
  _uniqueChannels(i, err);
  return r;
}

void _ladder(DeploymentInstance i, void Function(String) err) {
  final names = <String>{};
  if (i.levels.isEmpty) err('levels: at least one level is required');
  for (final (idx, l) in i.levels.indexed) {
    final p = 'level ${l.name}';
    if (!RegExp(r'^[a-z0-9][a-z0-9-]*$').hasMatch(l.name)) {
      err('$p: name must be lower-kebab-case');
    }
    if (!names.add(l.name)) err('$p: duplicate name');
    for (final cap in l.bindings.keys) {
      if (!i.capabilities.contains(cap)) err('$p: binds undeclared $cap');
    }
    if (l.built) {
      for (final cap in i.capabilities) {
        if ((l.bindings[cap] ?? '').isEmpty) {
          err('$p: built level must bind capability $cap');
        }
      }
    }
    for (final e in l.limits.entries) {
      if (e.value <= 0) err('$p: limit ${e.key} must be > 0');
    }
    if (l.paid) {
      final b = l.budget;
      if (b == null) {
        err('$p: paid level must declare a budget');
      } else {
        if (b.monthlyUsd <= 0) err('$p: budget.monthlyUsd must be > 0');
        if (b.alertThresholds.isEmpty || b.alertThresholds.any((t) => t <= 0)) {
          err('$p: budget.alertThresholds must be positive ratios');
        }
      }
    }
    if (idx == 0) continue;
    final m = l.migration;
    if (m == null) {
      err('$p: migration from ${i.levels[idx - 1].name} is required');
      continue;
    }
    final derived = transitionClass(i.levels[idx - 1], l);
    if (m.migrationClass.index < derived.index) {
      err(
        '$p: migration class ${m.migrationClass.name} understates the '
        'binding diff (at least ${derived.name})',
      );
    }
    if (m.steps.isEmpty) err('$p: migration needs at least one step');
  }
}

void _bands(Trigger t, String p, void Function(String) err) {
  if (t.warn <= 0) err('$p: warn must be > 0');
  final promote = t.promote;
  if (promote != null && !(t.warn < promote)) {
    err('$p: warn must be < promote');
  }
  final demote = t.demote;
  if (demote != null && !(demote >= 0 && demote < t.warn)) {
    err('$p: demote must be >= 0 and < warn');
  }
}

void _triggers(DeploymentInstance i, void Function(String) err) {
  final names = <String>{};
  for (final t in i.triggers) {
    final p = 'trigger ${t.name}';
    if (!names.add(t.name)) err('$p: duplicate name');
    if (!i.capabilities.contains(t.capability)) {
      err('$p: undeclared capability ${t.capability}');
    }
    if (!scalerTypes.contains(t.scaler.type)) {
      err('$p: unknown scaler ${t.scaler.type} (known: $scalerTypes)');
    }
    if (t.scaler.type == 'firestoreDailyOps' &&
        !{'read', 'write', 'delete'}.contains(t.scaler.params['op'])) {
      err('$p: firestoreDailyOps needs op read|write|delete');
    }
    _bands(t, p, err);
    for (final l in i.levels.where((l) => l.built && t.appliesTo(l))) {
      if (!l.limits.containsKey(t.limit)) {
        err('$p: limit ${t.limit} missing on level ${l.name}');
      }
    }
  }
}

void _environment(DeploymentInstance i, Environment env, ValidationReport r) {
  void err(String m) => r.errors.add(m);
  final p = 'environment ${env.name}';
  if (!flavors.contains(env.name)) err('$p: must be one of $flavors');
  for (final name in env.triggers.keys) {
    if (!i.triggers.any((t) => t.name == name)) {
      err('$p: override for unknown trigger $name');
    }
  }
  for (final other in env.sharedWith) {
    if (other == env.name || !i.environments.containsKey(other)) {
      err('$p: sharedWith $other is not another declared environment');
    }
  }
  final level = i.levelNamed(env.currentLevel);
  if (level == null) {
    err('$p: currentLevel ${env.currentLevel} is not a level');
    return;
  }
  if (!level.built) {
    err('$p: currentLevel ${env.currentLevel} must be a built level');
  }
  if (env.cloud &&
      env.provisioned &&
      level.provider == 'firebase' &&
      env.firebase == null) {
    err(
      '$p: firebase level needs firebase identity '
      '(or emulator: true, or provisioned: false)',
    );
  }
  if (env.emulator && !env.provisioned) {
    err('$p: emulator environments have nothing to provision');
  }
  final siteId = RegExp(r'^[a-z0-9]([a-z0-9-]{0,28}[a-z0-9])?$');
  bool validSite(String site) => siteId.firstMatch(site)?.end == site.length;
  final defaultSite = env.firebase?.siteId;
  if (defaultSite != null && !validSite(defaultSite)) {
    err('$p: Firebase site $defaultSite is not a Hosting site id');
  }
  final name = RegExp(r'^[a-z0-9][a-z0-9-]*$');
  for (final e in env.channels.entries) {
    if (!name.hasMatch(e.key)) err('$p: channel ${e.key} is not a branch name');
    final site = e.value;
    if (site != null && !validSite(site)) {
      err('$p: channel ${e.key} site $site is not a Hosting site id');
    }
    if (env.emulator) err('$p: emulator environments deploy no channels');
  }
  if (env.name == 'production' && env.emulator) {
    err('$p: production cannot run on emulators');
  }
  final d = Deployment(i, env);
  for (final t in d.triggers) {
    _bands(t, '$p trigger ${t.name}', err);
  }
  if (d.behavior.mode == Mode.auto) {
    final next = d.next;
    if (next == null ||
        next.migration?.migrationClass != MigrationClass.inPlace) {
      err('$p: mode auto is only allowed when the next transition is inPlace');
    }
  }
  if (d.behavior.stabilizationPolls < 1) {
    err('$p: stabilizationPolls must be >= 1');
  }
  if (env.cloud && d.activeTriggers(level).isEmpty) {
    r.warnings.add('$p: no active triggers on ${level.name}');
  }
}

/// No two environments may share a cloud project unless one lists the
/// other in `sharedWith`.
void _uniqueIdentities(DeploymentInstance i, void Function(String) err) {
  final envs = i.environments.values.toList();
  for (var a = 0; a < envs.length; a++) {
    for (var b = a + 1; b < envs.length; b++) {
      final x = envs[a];
      final y = envs[b];
      final shared =
          x.sharedWith.contains(y.name) || y.sharedWith.contains(x.name);
      if (shared) continue;
      final xf = x.firebase;
      final yf = y.firebase;
      if (xf != null && yf != null && xf.projectId == yf.projectId) {
        err(
          'environments ${x.name} and ${y.name} share Firebase project '
          '${xf.projectId}; declare sharedWith to allow it',
        );
      }
      final xs = x.supabase?.projectRef;
      if (xs != null && xs == y.supabase?.projectRef) {
        err(
          'environments ${x.name} and ${y.name} share Supabase project $xs; '
          'declare sharedWith to allow it',
        );
      }
    }
  }
}

/// A release channel deploys to exactly one environment.
void _uniqueChannels(DeploymentInstance i, void Function(String) err) {
  final owner = <String, String>{};
  for (final env in i.environments.values) {
    for (final channel in env.servedChannels) {
      final previous = owner[channel];
      if (previous != null) {
        err(
          'environments $previous and ${env.name} both deploy channel '
          '$channel',
        );
      }
      owner[channel] = env.name;
    }
  }
}

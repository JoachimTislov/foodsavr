import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart';

import 'model/behavior.dart';
import 'model/deployment_instance.dart';
import 'model/environment.dart';
import 'model/identity.dart';
import 'model/level.dart';
import 'model/trigger.dart';

/// Result of reading a manifest: the instance when it is structurally
/// sound, plus every structural error found (paths like `levels[1].plan`).
class ParseResult {
  const ParseResult(this.instance, this.errors);

  final DeploymentInstance? instance;
  final List<String> errors;
}

/// Reads the manifest at [path], deep-merged with [overlay] when given.
///
/// The tracked manifest holds the shared ladder only; the overlay holds the
/// instance state (repository, Firebase identities, Hosting sites) and comes
/// from [instanceOverlay].
ParseResult loadManifest(String path, {String? overlay}) {
  final file = File(path);
  if (!file.existsSync()) return ParseResult(null, ['$path: file not found']);
  return parseManifest(file.readAsStringSync(), overlay: overlay);
}

ParseResult parseManifest(String text, {String? overlay}) {
  Object? doc;
  try {
    doc = _plain(loadYaml(text));
  } on YamlException catch (e) {
    return ParseResult(null, ['yaml: ${e.message}']);
  }
  if (overlay != null && overlay.trim().isNotEmpty) {
    try {
      doc = _merge(doc, _plain(loadYaml(overlay)));
    } on YamlException catch (e) {
      return ParseResult(null, ['instance overlay: ${e.message}']);
    }
  }
  final r = _Reader();
  final instance = r.instance(doc);
  return ParseResult(r.errors.isEmpty ? instance : null, r.errors);
}

/// Overlay [over] onto [base]: mappings merge key by key, anything else
/// (scalars, lists, null) replaces.
Object? _merge(Object? base, Object? over) {
  if (base is Map<String, Object?> && over is Map<String, Object?>) {
    return {
      ...base,
      for (final e in over.entries) e.key: _merge(base[e.key], e.value),
    };
  }
  return over;
}

/// Instance overlay text for the repository manifest, from (first wins):
/// `DEPLOY_INSTANCE` (YAML or JSON; CI sets it from the GitHub Actions
/// variable of that name), then the `deployInstance` object of the gitignored
/// `.agents/instance.local.json` (FOODSAVR_INSTANCE_LOCAL overrides its path;
/// worktrees fall back to the main checkout's file). Null when unset: the
/// manifest then describes an unbound instance, as on a fresh fork.
String? instanceOverlay(String repoRoot, [Map<String, String>? environment]) {
  final env = environment ?? Platform.environment;
  final direct = env['DEPLOY_INSTANCE'];
  if (direct != null && direct.trim().isNotEmpty) return direct;
  for (final path in _localStatePaths(repoRoot, env)) {
    final file = File(path);
    if (!file.existsSync()) continue;
    try {
      final data = loadYaml(file.readAsStringSync());
      final overlay = data is YamlMap ? data['deployInstance'] : null;
      return overlay == null ? null : jsonEncode(_plain(overlay));
    } on YamlException {
      return null;
    }
  }
  return null;
}

Iterable<String> _localStatePaths(
  String repoRoot,
  Map<String, String> env,
) sync* {
  const relative = '.agents/instance.local.json';
  final override = env['FOODSAVR_INSTANCE_LOCAL'];
  if (override != null && override.isNotEmpty) {
    yield override;
    return;
  }
  yield '$repoRoot/$relative';
  try {
    final common = Process.runSync('git', [
      '-C',
      repoRoot,
      'rev-parse',
      '--path-format=absolute',
      '--git-common-dir',
    ]);
    final dir = '${common.stdout}'.trim();
    if (common.exitCode == 0 && dir.isNotEmpty) {
      yield '${File(dir).parent.path}/$relative';
    }
  } on ProcessException {
    // No git: only the worktree's own file applies.
  }
}

Object? _plain(Object? v) => switch (v) {
  YamlMap m => {for (final e in m.entries) '${e.key}': _plain(e.value)},
  YamlList l => [for (final e in l) _plain(e)],
  _ => v,
};

typedef _Map = Map<String, Object?>;

class _Reader {
  final errors = <String>[];

  void _err(String path, String msg) => errors.add('$path: $msg');

  _Map? _map(Object? v, String path, Set<String> allowed) {
    if (v is! Map) {
      _err(path, 'expected a mapping');
      return null;
    }
    final m = v.cast<String, Object?>();
    for (final k in m.keys.where((k) => !allowed.contains(k))) {
      _err('$path.$k', 'unknown key');
    }
    return m;
  }

  T? _get<T>(_Map m, String key, String path, {bool required = true}) {
    final v = m[key];
    if (v == null) {
      if (required) _err('$path.$key', 'required');
      return null;
    }
    if (v is! T) {
      _err('$path.$key', 'expected ${_typeName<T>()}, got ${v.runtimeType}');
      return null;
    }
    return v as T;
  }

  String _typeName<T>() => switch (T) {
    const (String) => 'a string',
    const (num) => 'a number',
    const (int) => 'an integer',
    const (bool) => 'a boolean',
    const (List) => 'a list',
    _ => '$T',
  };

  List<String> _strings(_Map m, String key, String path, {bool req = true}) {
    final l = _get<List>(m, key, path, required: req) ?? const [];
    if (l.any((e) => e is! String)) _err('$path.$key', 'expected strings');
    return l.whereType<String>().toList();
  }

  Map<String, T> _typedMap<T>(_Map m, String key, String path) {
    final v = m[key];
    if (v == null) {
      _err('$path.$key', 'required');
      return {};
    }
    if (v is! Map) {
      _err('$path.$key', 'expected a mapping');
      return {};
    }
    final out = <String, T>{};
    v.forEach((k, e) {
      if (e is T) {
        out['$k'] = e;
      } else {
        _err('$path.$key.$k', 'expected ${_typeName<T>()}');
      }
    });
    return out;
  }

  DeploymentInstance? instance(Object? doc) {
    const keys = {
      'version',
      'identity',
      'capabilities',
      'levels',
      'triggers',
      'behavior',
      'environments',
    };
    final m = _map(doc, 'manifest', keys);
    if (m == null) return null;
    final version = _get<int>(m, 'version', 'manifest');
    final identity = _identity(m['identity'], 'identity');
    final capabilities = _strings(m, 'capabilities', 'manifest');
    final levels = [
      for (final (i, l) in (_get<List>(m, 'levels', 'manifest') ?? []).indexed)
        _level(l, 'levels[$i]'),
    ];
    final triggers = [
      for (final (i, t)
          in (_get<List>(m, 'triggers', 'manifest') ?? []).indexed)
        _trigger(t, 'triggers[$i]'),
    ];
    final behavior = _behavior(m['behavior'], 'behavior');
    final environments = <String, Environment>{};
    final envs = _map(m['environments'], 'environments', flavors.toSet());
    envs?.forEach((name, v) {
      final e = _environment(name, v, 'environments.$name');
      if (e != null) environments[name] = e;
    });
    if (errors.isNotEmpty) return null;
    return DeploymentInstance(
      version: version!,
      identity: identity!,
      capabilities: capabilities,
      levels: levels.nonNulls.toList(),
      triggers: triggers.nonNulls.toList(),
      behavior: behavior!,
      environments: environments,
    );
  }

  Identity? _identity(Object? v, String p) {
    final m = _map(v, p, {'name', 'githubRepository', 'region'});
    if (m == null) return null;
    final name = _get<String>(m, 'name', p);
    final repo = _get<String>(m, 'githubRepository', p, required: false);
    final region = _get<String>(m, 'region', p);
    if (name == null || region == null) return null;
    return Identity(name: name, githubRepository: repo, region: region);
  }

  FirebaseIdentity? _firebase(Object? v, String p) {
    final f = _map(v, p, {'projectId', 'webAppId', 'webApiKeyId', 'siteId'});
    if (f == null) return null;
    final projectId = _get<String>(f, 'projectId', p);
    final webAppId = _get<String>(f, 'webAppId', p);
    if (projectId == null || webAppId == null) return null;
    return FirebaseIdentity(
      projectId: projectId,
      webAppId: webAppId,
      webApiKeyId: _get<String>(f, 'webApiKeyId', p, required: false),
      siteId: _get<String>(f, 'siteId', p, required: false),
    );
  }

  Environment? _environment(String name, Object? v, String p) {
    final m = _map(v, p, {
      'currentLevel',
      'emulator',
      'provisioned',
      'githubEnvironment',
      'firebase',
      'supabase',
      'sharedWith',
      'channels',
      'triggers',
      'behavior',
    });
    if (m == null) return null;
    final current = _get<String>(m, 'currentLevel', p);
    final emulator = _get<bool>(m, 'emulator', p, required: false) ?? false;
    final provisioned =
        _get<bool>(m, 'provisioned', p, required: false) ?? true;
    final channels = <String, String?>{};
    if (m['channels'] != null) {
      final c = m['channels'];
      if (c is! Map) _err('$p.channels', 'expected a mapping');
      if (c is Map) {
        c.forEach((k, site) {
          if (site != null && site is! String) {
            _err('$p.channels.$k', 'expected a Hosting site id or null');
          } else {
            channels['$k'] = site as String?;
          }
        });
      }
    }
    final ghEnv = _get<String>(m, 'githubEnvironment', p, required: false);
    final firebase = m['firebase'] == null
        ? null
        : _firebase(m['firebase'], '$p.firebase');
    SupabaseIdentity? supabase;
    if (m['supabase'] != null) {
      final s = _map(m['supabase'], '$p.supabase', {'projectRef'});
      final ref = s == null ? null : _get<String>(s, 'projectRef', p);
      if (ref != null) supabase = SupabaseIdentity(projectRef: ref);
    }
    final sharedWith = _strings(m, 'sharedWith', p, req: false);
    final overrides = <String, TriggerOverride>{};
    if (m['triggers'] != null) {
      final t = m['triggers'];
      if (t is! Map) _err('$p.triggers', 'expected a mapping');
      if (t is Map) {
        for (final e in t.entries) {
          final o = _map(e.value, '$p.triggers.${e.key}', {
            'warn',
            'promote',
            'demote',
            'enabled',
          });
          if (o == null) continue;
          final tp = '$p.triggers.${e.key}';
          overrides['${e.key}'] = TriggerOverride(
            warn: _get<num>(o, 'warn', tp, required: false)?.toDouble(),
            promote: _get<num>(o, 'promote', tp, required: false)?.toDouble(),
            demote: _get<num>(o, 'demote', tp, required: false)?.toDouble(),
            enabled: _get<bool>(o, 'enabled', tp, required: false) ?? true,
          );
        }
      }
    }
    BehaviorOverride? behavior;
    if (m['behavior'] != null) {
      final b = _map(m['behavior'], '$p.behavior', {
        'pollingInterval',
        'stabilizationPolls',
        'minDwell',
        'mode',
      });
      if (b != null) {
        Duration? duration(String key) {
          if (b[key] == null) return null;
          final d = parseDuration(b[key]);
          if (d == null) _err('$p.behavior.$key', 'expected a duration');
          return d;
        }

        final mode = b['mode'] == null
            ? null
            : Mode.values.where((x) => x.name == b['mode']).firstOrNull;
        if (b['mode'] != null && mode == null) {
          _err('$p.behavior.mode', 'expected recommend or auto');
        }
        behavior = BehaviorOverride(
          pollingInterval: duration('pollingInterval'),
          stabilizationPolls: _get<int>(
            b,
            'stabilizationPolls',
            '$p.behavior',
            required: false,
          ),
          minDwell: duration('minDwell'),
          mode: mode,
        );
      }
    }
    if (current == null) return null;
    return Environment(
      name: name,
      currentLevel: current,
      emulator: emulator,
      provisioned: provisioned,
      githubEnvironment: ghEnv,
      firebase: firebase,
      supabase: supabase,
      sharedWith: sharedWith,
      channels: channels,
      triggers: overrides,
      behavior: behavior,
    );
  }

  Level? _level(Object? v, String p) {
    final m = _map(v, p, {
      'name',
      'provider',
      'plan',
      'status',
      'paid',
      'limits',
      'bindings',
      'requires',
      'budget',
      'migration',
      'notes',
    });
    if (m == null) return null;
    final status = LevelStatus.parse(m['status']);
    if (status == null) _err('$p.status', 'expected built or spec-ahead');
    final name = _get<String>(m, 'name', p);
    final provider = _get<String>(m, 'provider', p);
    final plan = _get<String>(m, 'plan', p);
    final paid = _get<bool>(m, 'paid', p);
    final limits = _typedMap<num>(m, 'limits', p);
    final bindings = _typedMap<String>(m, 'bindings', p);
    final requires = _strings(m, 'requires', p, req: false);
    final budget = m['budget'] == null
        ? null
        : _budget(m['budget'], '$p.budget');
    final migration = m['migration'] == null
        ? null
        : _migration(m['migration'], '$p.migration');
    final notes = _get<String>(m, 'notes', p, required: false);
    if ([name, provider, plan, paid, status].contains(null)) return null;
    return Level(
      name: name!,
      provider: provider!,
      plan: plan!,
      status: status!,
      paid: paid!,
      limits: limits,
      bindings: bindings,
      requires: requires,
      budget: budget,
      migration: migration,
      notes: notes,
    );
  }

  Budget? _budget(Object? v, String p) {
    final m = _map(v, p, {'monthlyUsd', 'alertThresholds', 'killSwitch'});
    if (m == null) return null;
    final usd = _get<num>(m, 'monthlyUsd', p);
    final thresholds = _get<List>(m, 'alertThresholds', p) ?? const [];
    if (thresholds.any((t) => t is! num)) {
      _err('$p.alertThresholds', 'expected numbers');
    }
    final kill = _get<bool>(m, 'killSwitch', p, required: false) ?? false;
    if (usd == null) return null;
    return Budget(
      monthlyUsd: usd,
      alertThresholds: [
        for (final t in thresholds.whereType<num>()) t.toDouble(),
      ],
      killSwitch: kill,
    );
  }

  Migration? _migration(Object? v, String p) {
    final m = _map(v, p, {'class', 'reversible', 'steps'});
    if (m == null) return null;
    final cls = MigrationClass.parse(m['class']);
    if (cls == null) {
      _err(
        '$p.class',
        'expected one of ${MigrationClass.values.map((c) => c.name)}',
      );
    }
    final reversible = _get<bool>(m, 'reversible', p);
    final steps = _strings(m, 'steps', p);
    if (cls == null || reversible == null) return null;
    return Migration(migrationClass: cls, reversible: reversible, steps: steps);
  }

  Trigger? _trigger(Object? v, String p) {
    final m = _map(v, p, {
      'name',
      'capability',
      'binding',
      'scaler',
      'limit',
      'warn',
      'promote',
      'demote',
      'description',
    });
    if (m == null) return null;
    ScalerSpec? scaler;
    final s = m['scaler'];
    if (s is Map) {
      final sm = s.cast<String, Object?>();
      final type = _get<String>(sm, 'type', '$p.scaler');
      if (type != null) {
        scaler = ScalerSpec(type: type, params: {...sm}..remove('type'));
      }
    } else {
      _err('$p.scaler', 'expected a mapping with a type');
    }
    final name = _get<String>(m, 'name', p);
    final capability = _get<String>(m, 'capability', p);
    final binding = _get<String>(m, 'binding', p);
    final limit = _get<String>(m, 'limit', p);
    final warn = _get<num>(m, 'warn', p);
    final promote = _get<num>(m, 'promote', p, required: false);
    final demote = _get<num>(m, 'demote', p, required: false);
    final description = _get<String>(m, 'description', p, required: false);
    if ([name, capability, binding, limit, warn, scaler].contains(null)) {
      return null;
    }
    return Trigger(
      name: name!,
      capability: capability!,
      binding: binding!,
      scaler: scaler!,
      limit: limit!,
      warn: warn!.toDouble(),
      promote: promote?.toDouble(),
      demote: demote?.toDouble(),
      description: description,
    );
  }

  Behavior? _behavior(Object? v, String p) {
    final m = _map(v, p, {
      'pollingInterval',
      'stabilizationPolls',
      'minDwell',
      'mode',
      'fallback',
    });
    if (m == null) return null;
    Duration? duration(String key) {
      final d = parseDuration(m[key]);
      if (d == null) _err('$p.$key', 'expected a duration like 24h or 30d');
      return d;
    }

    final interval = duration('pollingInterval');
    final dwell = duration('minDwell');
    final polls = _get<int>(m, 'stabilizationPolls', p);
    final mode = Mode.values.where((x) => x.name == m['mode']).firstOrNull;
    if (mode == null) _err('$p.mode', 'expected recommend or auto');
    var fallback = const Fallback();
    if (m['fallback'] != null) {
      final f = _map(m['fallback'], '$p.fallback', {
        'action',
        'alertAfterFailures',
      });
      if (f != null) {
        final action = _get<String>(f, 'action', '$p.fallback');
        if (action != null && action != 'hold') {
          _err('$p.fallback.action', 'only hold is supported');
        }
        fallback = Fallback(
          alertAfterFailures:
              _get<int>(f, 'alertAfterFailures', '$p.fallback') ?? 3,
        );
      }
    }
    if (interval == null || dwell == null || polls == null || mode == null) {
      return null;
    }
    return Behavior(
      pollingInterval: interval,
      stabilizationPolls: polls,
      minDwell: dwell,
      mode: mode,
      fallback: fallback,
    );
  }
}

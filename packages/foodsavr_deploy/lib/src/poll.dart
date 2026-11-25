import 'deployment.dart';
import 'model/trigger.dart';
import 'plan.dart';
import 'scalers.dart';

enum Band { ok, warn, promote, demote }

/// Band of [ratio] for [t]: promote ≥ promote > warn ≥ warn > ok > demote ≥.
Band bandOf(Trigger t, double ratio) {
  final promote = t.promote;
  final demote = t.demote;
  if (promote != null && ratio >= promote) return Band.promote;
  if (ratio >= t.warn) return Band.warn;
  if (demote != null && ratio <= demote) return Band.demote;
  return Band.ok;
}

class TriggerState {
  TriggerState({this.band, this.streak = 0, this.failures = 0});

  factory TriggerState.fromJson(Map<String, Object?> j) => TriggerState(
    band: Band.values.where((b) => b.name == j['band']).firstOrNull,
    streak: (j['streak'] as num?)?.toInt() ?? 0,
    failures: (j['failures'] as num?)?.toInt() ?? 0,
  );

  Band? band;

  /// Consecutive polls in [band].
  int streak;

  /// Consecutive failed reads.
  int failures;

  Map<String, Object?> toJson() => {
    'band': band?.name,
    'streak': streak,
    'failures': failures,
  };
}

/// Persisted between polls (stabilization, dwell, failure counts).
class PollState {
  PollState({this.level, this.levelSince, Map<String, TriggerState>? triggers})
    : triggers = triggers ?? {};

  factory PollState.fromJson(Map<String, Object?> j) => PollState(
    level: j['level'] as String?,
    levelSince: DateTime.tryParse('${j['levelSince']}'),
    triggers: {
      for (final e in ((j['triggers'] as Map?) ?? const {}).entries)
        '${e.key}': TriggerState.fromJson(
          (e.value as Map).cast<String, Object?>(),
        ),
    },
  );

  String? level;
  DateTime? levelSince;
  final Map<String, TriggerState> triggers;

  Map<String, Object?> toJson() => {
    'level': level,
    'levelSince': levelSince?.toUtc().toIso8601String(),
    'triggers': {for (final e in triggers.entries) e.key: e.value.toJson()},
  };
}

class Reading {
  Reading(this.trigger, {this.value, this.limit, this.state, this.note});

  final Trigger trigger;
  final double? value;
  final num? limit;
  final TriggerState? state;

  /// Error or skip reason.
  final String? note;

  double? get ratio =>
      value == null || limit == null ? null : value! / limit!.toDouble();

  Map<String, Object?> toJson() => {
    'trigger': trigger.name,
    'limitKey': trigger.limit,
    'value': value,
    'limit': limit,
    'ratio': ratio == null ? null : double.parse(ratio!.toStringAsFixed(4)),
    'band': state?.band?.name,
    'streak': state?.streak,
    'failures': state?.failures,
    'note': note,
  };
}

class PollResult {
  PollResult({
    required this.action,
    required this.environment,
    required this.level,
    required this.reasons,
    required this.readings,
    required this.state,
    this.target,
    this.plan,
    this.autoEligible = false,
  });

  /// hold | warn | promote | demote
  final String action;
  final String environment;
  final String level;
  final String? target;
  final List<String> reasons;
  final List<Reading> readings;
  final PollState state;
  final TransitionPlan? plan;

  /// Mode is auto and the recommended transition is inPlace. Informational:
  /// phase 1 never executes transitions.
  final bool autoEligible;

  Map<String, Object?> toJson() => {
    'environment': environment,
    'level': level,
    'recommendation': {
      'action': action,
      'target': target,
      'reasons': reasons,
      'autoEligible': autoEligible,
    },
    'readings': [for (final r in readings) r.toJson()],
    'plan': plan?.toJson(),
  };

  String toMarkdown() {
    final b = StringBuffer()
      ..writeln('# Deployment level ($environment): `$level` → **$action**')
      ..writeln();
    if (target != null) b.writeln('Target: `$target`\n');
    for (final r in reasons) {
      b.writeln('- $r');
    }
    b
      ..writeln()
      ..writeln('| Trigger | Value | Limit | Ratio | Band | Streak | Note |')
      ..writeln('|---|---|---|---|---|---|---|');
    for (final r in readings) {
      String f(num? n) => n == null ? '—' : _fmt(n);
      b.writeln(
        '| ${r.trigger.name} | ${f(r.value)} | ${f(r.limit)} '
        '${r.trigger.limit} | ${r.ratio == null ? '—' : '${(r.ratio! * 100).toStringAsFixed(1)}%'} '
        '| ${r.state?.band?.name ?? '—'} | ${r.state?.streak ?? '—'} '
        '| ${r.note ?? ''} |',
      );
    }
    if (plan != null) b.writeln('\n${plan!.toMarkdown()}');
    return b.toString();
  }
}

String _fmt(num n) => n == n.roundToDouble() && n.abs() < 1e15
    ? n.toInt().toString()
    : n.toStringAsFixed(3);

/// One evaluation of every trigger active on the current level. Updates
/// [state] in place; never mutates infrastructure.
Future<PollResult> poll(
  Deployment i,
  PollState state,
  Map<String, Scaler> scalers, {
  DateTime? now,
}) async {
  if (!i.environment.provisioned) {
    return PollResult(
      action: 'hold',
      environment: i.flavor,
      level: i.currentLevel,
      reasons: ['unprovisioned environment: not polled'],
      readings: [],
      state: state,
    );
  }
  final at = (now ?? DateTime.now()).toUtc();
  final level = i.current;
  final b = i.behavior;
  if (state.level != level.name) {
    state
      ..level = level.name
      ..levelSince = at
      ..triggers.clear();
  }
  final readings = <Reading>[];
  final reasons = <String>[];
  // Emulator environments have no cloud usage to measure.
  final emulator = i.environment.emulator;
  if (emulator) reasons.add('emulator environment: not polled');
  for (final t in emulator ? const <Trigger>[] : i.activeTriggers(level)) {
    final s = state.triggers.putIfAbsent(t.name, TriggerState.new);
    final limit = level.limits[t.limit];
    if (t.scaler.type == 'deployGuard') {
      readings.add(
        Reading(
          t,
          limit: limit,
          note:
              'checked at deploy time (${t.scaler.params['script'] ?? 'guard'})',
        ),
      );
      continue;
    }
    final scaler = scalers[t.scaler.type];
    try {
      if (scaler == null) throw StateError('no ${t.scaler.type} scaler');
      if (limit == null) throw StateError('no limit ${t.limit}');
      final value = await scaler.read(t, i);
      final band = bandOf(t, value / limit);
      s
        ..failures = 0
        ..streak = s.band == band ? s.streak + 1 : 1
        ..band = band;
      readings.add(Reading(t, value: value, limit: limit, state: s));
    } catch (e) {
      // Missing reads break consecutive evidence, while retaining the last
      // observed band for diagnostics.
      s
        ..failures += 1
        ..streak = 0;
      readings.add(Reading(t, limit: limit, state: s, note: 'error: $e'));
    }
  }

  final n = b.stabilizationPolls;
  final measured = readings.where((r) => r.value != null).toList();
  final failing = readings.where((r) => r.note?.startsWith('error') ?? false);
  final stablePromote = measured.where(
    (r) => r.state!.band == Band.promote && r.state!.streak >= n,
  );
  final pending = measured.where(
    (r) => r.state!.band == Band.warn || r.state!.band == Band.promote,
  );
  final alerting = failing.where(
    (r) => r.state!.failures >= b.fallback.alertAfterFailures,
  );

  var action = 'hold';
  String? target;
  if (stablePromote.isNotEmpty) {
    final next = i.next;
    final names = stablePromote.map((r) => r.trigger.name).join(', ');
    if (next == null) {
      action = 'warn';
      reasons.add(
        '$names over promote band but ${level.name} is the top level',
      );
    } else {
      action = 'promote';
      target = next.name;
      reasons.add('$names in promote band for $n+ polls');
    }
  } else if (pending.isNotEmpty || alerting.isNotEmpty) {
    action = 'warn';
    for (final r in pending) {
      reasons.add(
        '${r.trigger.name} in ${r.state!.band!.name} band '
        '(${r.state!.band == Band.promote ? '${r.state!.streak}/$n polls to promote' : '${r.state!.streak} polls'})',
      );
    }
    for (final r in alerting) {
      reasons.add(
        '${r.trigger.name} unreadable for ${r.state!.failures} polls; holding',
      );
    }
  } else if (failing.isEmpty &&
      i.previous != null &&
      // Triggers without a demote band are neutral (they are below warn).
      measured.any((r) => r.trigger.demote != null) &&
      measured
          .where((r) => r.trigger.demote != null)
          .every((r) => r.state!.band == Band.demote && r.state!.streak >= n)) {
    final dwell = at.difference(state.levelSince ?? at);
    if (dwell >= b.minDwell) {
      action = 'demote';
      target = i.previous!.name;
      reasons.add('all triggers in demote band for $n+ polls');
    } else {
      reasons.add(
        'demote band held, but minDwell not reached '
        '(${dwell.inHours}h of ${b.minDwell.inHours}h)',
      );
    }
  }
  if (failing.isNotEmpty && alerting.isEmpty) {
    reasons.add(
      '${failing.map((r) => r.trigger.name).join(', ')} unreadable; '
      'holding their last band',
    );
  }
  if (action == 'hold' && reasons.isEmpty) reasons.add('within limits');
  final plan = target == null ? null : planTransition(i, to: target);
  return PollResult(
    action: action,
    environment: i.flavor,
    level: level.name,
    target: target,
    reasons: reasons,
    readings: readings,
    state: state,
    plan: plan,
    autoEligible: plan != null && !plan.approvalRequired,
  );
}

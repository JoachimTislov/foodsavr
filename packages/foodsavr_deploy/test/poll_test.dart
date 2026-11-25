import 'package:foodsavr_deploy/foodsavr_deploy.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

class _Failing implements Scaler {
  @override
  String get type => 'file';

  @override
  Future<double> read(Trigger t, Deployment d) async =>
      throw StateError('down');
}

void main() {
  final t0 = DateTime.utc(2026, 1, 1);
  late Deployment prod;
  setUp(() => prod = Deployment.of(load(baseManifest()), 'production'));

  /// Polls once per metrics map, one day apart, sharing state.
  Future<List<PollResult>> run(
    List<Map<String, double>> polls, {
    PollState? state,
    Deployment? d,
    DateTime? start,
  }) async {
    final s = state ?? PollState();
    final out = <PollResult>[];
    for (final (n, metrics) in polls.indexed) {
      out.add(
        await poll(d ?? prod, s, {
          'file': FileScaler(metrics),
        }, now: (start ?? t0).add(Duration(days: n))),
      );
    }
    return out;
  }

  test('unprovisioned environments leave poll state untouched', () async {
    final manifest = baseManifest();
    manifest['environments']['production']['provisioned'] = false;
    manifest['environments']['production'].remove('firebase');
    final d = Deployment.of(load(manifest), 'production');
    final state = PollState(level: 'previous');
    final result = await poll(d, state, {'file': _Failing()});
    expect(result.action, 'hold');
    expect(result.reasons, ['unprovisioned environment: not polled']);
    expect(result.readings, isEmpty);
    expect(state.level, 'previous');
    expect(state.triggers, isEmpty);
  });

  test('bandOf maps ratios to bands', () {
    final t = prod.triggers.first; // warn .7, promote .9, demote .3
    expect(bandOf(t, 0.95), Band.promote);
    expect(bandOf(t, 0.9), Band.promote);
    expect(bandOf(t, 0.75), Band.warn);
    expect(bandOf(t, 0.5), Band.ok);
    expect(bandOf(t, 0.3), Band.demote);
  });

  test('within limits holds', () async {
    final [r] = await run([
      {'users': 500, 'reads': 50},
    ]);
    expect(r.action, 'hold');
    expect(r.readings.first.ratio, 0.5);
  });

  test('promote needs stabilizationPolls consecutive breaches', () async {
    final results = await run([
      {'users': 950, 'reads': 10},
      {'users': 950, 'reads': 10},
    ]);
    expect(results[0].action, 'warn');
    expect(results[0].reasons.first, contains('1/2 polls to promote'));
    expect(results[1].action, 'promote');
    expect(results[1].target, 'blaze');
    expect(results[1].plan!.migrationClass, MigrationClass.inPlace);
  });

  test('a dip resets the streak (stabilization)', () async {
    final results = await run([
      {'users': 950, 'reads': 50},
      {'users': 500, 'reads': 50},
      {'users': 950, 'reads': 50},
    ]);
    expect(results.map((r) => r.action), ['warn', 'hold', 'warn']);
  });

  test('missing data holds and never promotes (fallback)', () async {
    final s = PollState();
    await run([
      {'users': 950, 'reads': 10},
    ], state: s);
    // Second poll: users unreadable. Its promote streak must not advance.
    final [r] = await run(
      [
        {'reads': 10},
      ],
      state: s,
      start: t0.add(const Duration(days: 1)),
    );
    expect(r.action, isNot('promote'));
    expect(s.triggers['users']!.failures, 1);
    expect(s.triggers['users']!.streak, 0);
    expect(r.reasons.join(), contains('users unreadable'));
  });

  test('recovered metrics need a fresh consecutive promotion streak', () async {
    final results = await run([
      {'users': 950, 'reads': 10},
      {'reads': 10},
      {'users': 950, 'reads': 10},
      {'users': 950, 'reads': 10},
    ]);
    expect(results.map((r) => r.action), ['warn', 'hold', 'warn', 'promote']);
    expect(results[2].reasons.first, contains('1/2 polls to promote'));
  });

  test('repeated metric failures alert as warn', () async {
    final s = PollState();
    final d = prod;
    PollResult? last;
    for (var n = 0; n < 2; n++) {
      last = await poll(d, s, {'file': _Failing()}, now: t0);
    }
    expect(last!.action, 'warn');
    expect(last.reasons.join(), contains('unreadable for 2 polls'));
  });

  test(
    'demote requires all demote bands, stabilization and minDwell',
    () async {
      final m = baseManifest();
      m['environments']['production']['currentLevel'] = 'blaze';
      final blaze = Deployment.of(load(m), 'production');
      final low = {'users': 100.0, 'reads': 10.0}; // 0.01 ratios
      final early = await run([low, low], d: blaze);
      expect(early.last.action, 'hold');
      expect(early.last.reasons.first, contains('minDwell'));

      final s = PollState();
      final results = await run(
        [for (var n = 0; n < 8; n++) low],
        state: s,
        d: blaze,
      );
      expect(results.last.action, 'demote');
      expect(results.last.target, 'spark');
    },
  );

  test('hysteresis: between demote and warn nothing happens', () async {
    final m = baseManifest();
    m['environments']['production']['currentLevel'] = 'blaze';
    final blaze = Deployment.of(load(m), 'production');
    final mid = {'users': 5000.0, 'reads': 400.0}; // 0.5 / 0.4
    final results = await run([for (var n = 0; n < 10; n++) mid], d: blaze);
    expect(results.every((r) => r.action == 'hold'), isTrue);
  });

  test('state resets when the environment changes level', () async {
    final s = PollState();
    await run([
      {'users': 950, 'reads': 10},
    ], state: s);
    final m = baseManifest();
    m['environments']['production']['currentLevel'] = 'blaze';
    final blaze = Deployment.of(load(m), 'production');
    await run(
      [
        {'users': 100, 'reads': 10},
      ],
      state: s,
      d: blaze,
    );
    expect(s.level, 'blaze');
    expect(s.triggers['users']!.band, Band.demote);
    expect(s.triggers['users']!.streak, 1);
  });

  test('state round-trips through JSON', () async {
    final s = PollState();
    await run([
      {'users': 950, 'reads': 10},
    ], state: s);
    final back = PollState.fromJson(s.toJson());
    expect(back.level, 'spark');
    expect(back.triggers['users']!.band, Band.promote);
    expect(back.levelSince, t0);
  });

  test('emulator environments are not polled', () async {
    final dev = Deployment.of(load(baseManifest()), 'development');
    final [r] = await run([
      {'users': 999},
    ], d: dev);
    expect(r.action, 'hold');
    expect(r.readings, isEmpty);
    expect(r.environment, 'development');
  });

  test('per-environment overrides change the bands', () async {
    final m = baseManifest();
    m['environments']['production']['triggers'] = {
      'users': {'warn': 0.4, 'promote': 0.5},
      'reads': {'enabled': false},
    };
    final d = Deployment.of(load(m), 'production');
    expect(d.triggers.map((t) => t.name), ['users']);
    final [r] = await run([
      {'users': 450},
    ], d: d);
    expect(r.action, 'warn');
  });
}

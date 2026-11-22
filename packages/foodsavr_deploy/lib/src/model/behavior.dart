enum Mode {
  /// Emit recommendations only (default).
  recommend,

  /// Reserved: run `inPlace` promotions without a per-transition approval.
  /// Phase 1 has no executor.
  auto,
}

/// What to do when a metric cannot be read: always hold (never promote on
/// missing data) and alert after [alertAfterFailures] consecutive failures.
class Fallback {
  const Fallback({this.action = 'hold', this.alertAfterFailures = 3});

  final String action;
  final int alertAfterFailures;
}

class Behavior {
  const Behavior({
    required this.pollingInterval,
    required this.stabilizationPolls,
    required this.minDwell,
    this.mode = Mode.recommend,
    this.fallback = const Fallback(),
  });

  final Duration pollingInterval;

  /// Consecutive polls in a promote/demote band before recommending it.
  final int stabilizationPolls;

  /// Minimum time on a level before a demotion is recommended (cooldown).
  final Duration minDwell;
  final Mode mode;
  final Fallback fallback;
}

/// Parses `30m`, `24h`, `7d`, `2w`; null when malformed.
Duration? parseDuration(Object? v) {
  final m = RegExp(r'^(\d+)([mhdw])$').firstMatch('${v ?? ''}');
  if (m == null) return null;
  final n = int.parse(m.group(1)!);
  return switch (m.group(2)) {
    'm' => Duration(minutes: n),
    'h' => Duration(hours: n),
    'd' => Duration(days: n),
    _ => Duration(days: 7 * n),
  };
}

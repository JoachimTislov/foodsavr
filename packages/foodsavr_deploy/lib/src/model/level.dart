/// Whether the repository can run a level today.
enum LevelStatus {
  built('built'),
  specAhead('spec-ahead');

  const LevelStatus(this.id);
  final String id;

  static LevelStatus? parse(Object? v) =>
      LevelStatus.values.where((s) => s.id == v).firstOrNull;
}

/// How disruptive a level transition is, least to most.
enum MigrationClass {
  /// Same provider and bindings; only the plan changes (e.g. Spark→Blaze).
  inPlace,

  /// Stateless capabilities (hosting, appCheck) move; no user data moves.
  redeploy,

  /// Documents or blobs move to another provider.
  dataMove,

  /// User accounts move to another provider.
  authMove;

  static MigrationClass? parse(Object? v) =>
      MigrationClass.values.where((c) => c.name == v).firstOrNull;

  /// Only [inPlace] transitions may run without a per-transition approval.
  bool get requiresApproval => this != inPlace;

  MigrationClass max(MigrationClass other) =>
      other.index > index ? other : this;
}

/// Spend guard a paid level must declare. Provider budgets only alert;
/// [killSwitch] opts into disabling billing once the budget is exceeded.
class Budget {
  const Budget({
    required this.monthlyUsd,
    required this.alertThresholds,
    this.killSwitch = false,
  });

  final num monthlyUsd;
  final List<double> alertThresholds;
  final bool killSwitch;
}

/// How to move into a level from the level before it in the ladder.
class Migration {
  const Migration({
    required this.migrationClass,
    required this.reversible,
    required this.steps,
  });

  final MigrationClass migrationClass;
  final bool reversible;
  final List<String> steps;
}

class Level {
  const Level({
    required this.name,
    required this.provider,
    required this.plan,
    required this.status,
    required this.paid,
    required this.limits,
    required this.bindings,
    this.requires = const [],
    this.budget,
    this.migration,
    this.notes,
  });

  final String name;
  final String provider;
  final String plan;
  final LevelStatus status;
  final bool paid;

  /// Usage limits keyed with unit and period, e.g. `firestoreReadsPerDay`.
  final Map<String, num> limits;

  /// Capability → `provider/service` implementing it, or `none`.
  final Map<String, String> bindings;
  final List<String> requires;
  final Budget? budget;
  final Migration? migration;
  final String? notes;

  bool get built => status == LevelStatus.built;
}

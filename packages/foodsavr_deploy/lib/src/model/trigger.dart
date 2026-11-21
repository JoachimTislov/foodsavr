import 'level.dart';

/// Pluggable metric source for a trigger (KEDA scaler analogue).
class ScalerSpec {
  const ScalerSpec({required this.type, this.params = const {}});

  final String type;
  final Map<String, Object?> params;
}

/// Compares a metric to a limit of the current level. Bands are ratios of
/// usage to that limit: `>= promote` promotes, `>= warn` warns, `<= demote`
/// may demote. The gaps between bands are the hysteresis.
class Trigger {
  const Trigger({
    required this.name,
    required this.capability,
    required this.binding,
    required this.scaler,
    required this.limit,
    required this.warn,
    this.promote,
    this.demote,
    this.description,
  });

  final String name;
  final String capability;

  /// `provider/service` the metric measures; the trigger is active on levels
  /// that bind [capability] to it.
  final String binding;
  final ScalerSpec scaler;

  /// Limit key on the current level; the metric uses that key's unit.
  final String limit;
  final double warn;
  final double? promote;
  final double? demote;
  final String? description;

  bool appliesTo(Level level) => level.bindings[capability] == binding;
}

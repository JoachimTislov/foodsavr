import 'matcher.dart';

/// What the pipeline decided for an item.
enum ConfidenceDecision { autoAdd, confirm, hold }

/// The confidence gate: turns a [MatchResult] into a decision.
///
/// - [autoAdd]: high confidence, add to inventory without user interaction.
/// - [confirm]: plausible match, surface for one-tap confirmation.
/// - [hold]: too weak (or contradictory) — keep out of inventory.
class ConfidenceGate {
  const ConfidenceGate({
    this.autoAddThreshold = 0.85,
    this.confirmThreshold = 0.55,
  });

  /// Confidence at/above which items are added without confirmation.
  final double autoAddThreshold;

  /// Confidence at/above which items are worth confirming.
  final double confirmThreshold;

  ConfidenceDecision decide(MatchResult match) {
    if (match.confidence >= autoAddThreshold) {
      return ConfidenceDecision.autoAdd;
    }
    if (match.confidence >= confirmThreshold) {
      return ConfidenceDecision.confirm;
    }
    return ConfidenceDecision.hold;
  }

  /// Decides for a batch; order preserved.
  List<ConfidenceDecision> decideAll(Iterable<MatchResult> matches) =>
      matches.map(decide).toList();
}

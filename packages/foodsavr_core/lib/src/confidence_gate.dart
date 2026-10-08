import 'line_item.dart';

/// Decision the confidence gate returns for an ingested item.
enum GateDecision { autoAdd, confirm, hold }

/// Classifies ingested items by match confidence:
/// high -> auto-add, medium -> confirm, low -> hold.
class ConfidenceGate {
  const ConfidenceGate({
    double autoAddThreshold = 0.85,
    double confirmThreshold = 0.5,
  }) : _autoAdd = autoAddThreshold,
       _confirm = confirmThreshold;

  final double _autoAdd;
  final double _confirm;

  GateDecision evaluate(LineItem item) {
    final confidence = item.matchConfidence;
    if (confidence == null || confidence < _confirm) return GateDecision.hold;
    if (confidence >= _autoAdd) return GateDecision.autoAdd;
    return GateDecision.confirm;
  }
}

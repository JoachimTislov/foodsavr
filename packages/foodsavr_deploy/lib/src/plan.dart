import 'model/behavior.dart';
import 'deployment.dart';
import 'model/level.dart';
import 'validate.dart';

class BindingChange {
  const BindingChange(this.capability, this.from, this.to);

  final String capability;
  final String? from;
  final String? to;

  Map<String, Object?> toJson() => {
    'capability': capability,
    'from': from,
    'to': to,
  };
}

/// What moving the instance from its current level to [to] involves.
/// Describes only; nothing here mutates infrastructure.
class TransitionPlan {
  const TransitionPlan({
    required this.from,
    required this.to,
    required this.direction,
    required this.migrationClass,
    required this.reversible,
    required this.approvalRequired,
    required this.enablesBilling,
    required this.declared,
    required this.bindingChanges,
    required this.steps,
  });

  final Level from;
  final Level to;

  /// `promote`, `demote` or `jump` (non-adjacent).
  final String direction;
  final MigrationClass migrationClass;
  final bool reversible;
  final bool approvalRequired;
  final bool enablesBilling;

  /// Steps come from the manifest (adjacent levels) rather than the diff.
  final bool declared;
  final List<BindingChange> bindingChanges;
  final List<String> steps;

  bool get executable => to.built;

  Map<String, Object?> toJson() => {
    'from': from.name,
    'to': to.name,
    'direction': direction,
    'class': migrationClass.name,
    'reversible': reversible,
    'approvalRequired': approvalRequired,
    'enablesBilling': enablesBilling,
    'budget': to.budget == null
        ? null
        : {
            'monthlyUsd': to.budget!.monthlyUsd,
            'alertThresholds': to.budget!.alertThresholds,
            'killSwitch': to.budget!.killSwitch,
          },
    'targetStatus': to.status.id,
    'executable': executable,
    'declaredSteps': declared,
    'bindingChanges': [for (final c in bindingChanges) c.toJson()],
    'requires': to.requires,
    'steps': steps,
  };

  String toMarkdown() {
    final b = StringBuffer()
      ..writeln('## ${from.name} → ${to.name} ($direction)')
      ..writeln()
      ..writeln('| | |')
      ..writeln('|---|---|')
      ..writeln('| Class | `${migrationClass.name}` |')
      ..writeln('| Reversible | ${reversible ? 'yes' : 'no'} |')
      ..writeln('| Approval required | ${approvalRequired ? 'yes' : 'no'} |')
      ..writeln('| Enables billing | ${enablesBilling ? 'yes' : 'no'} |')
      ..writeln('| Target status | ${to.status.id} |');
    if (to.budget != null) {
      b.writeln('| Budget | ${to.budget!.monthlyUsd} USD/month |');
    }
    if (!executable) {
      b
        ..writeln()
        ..writeln('> Target is spec-ahead: the repository cannot run it yet.');
    }
    if (bindingChanges.isNotEmpty) {
      b
        ..writeln()
        ..writeln('Binding changes:');
      for (final c in bindingChanges) {
        b.writeln('- `${c.capability}`: ${c.from ?? '—'} → ${c.to ?? '—'}');
      }
    }
    if (to.requires.isNotEmpty) {
      b
        ..writeln()
        ..writeln('Requires: ${to.requires.join(', ')}');
    }
    b
      ..writeln()
      ..writeln('Steps${declared ? '' : ' (derived from binding diff)'}:');
    for (final (n, s) in steps.indexed) {
      b.writeln('${n + 1}. $s');
    }
    return b.toString();
  }
}

/// Plans current level → [to] (default: next level). Null when there is no
/// such target.
TransitionPlan? planTransition(Deployment i, {String? to}) {
  final from = i.current;
  final target = to == null ? i.next : i.levelNamed(to);
  if (target == null || target.name == from.name) return null;
  final fi = i.indexOf(from.name);
  final ti = i.indexOf(target.name);
  final changes = [
    for (final cap in i.capabilities)
      if (from.bindings[cap] != target.bindings[cap])
        BindingChange(cap, from.bindings[cap], target.bindings[cap]),
  ];
  final cls = transitionClass(from, target);
  String direction;
  bool declared;
  bool reversible;
  List<String> steps;
  if (ti == fi + 1 && target.migration != null) {
    direction = 'promote';
    declared = true;
    reversible = target.migration!.reversible;
    steps = target.migration!.steps;
  } else if (ti == fi - 1 && from.migration != null) {
    direction = 'demote';
    declared = true;
    reversible = from.migration!.reversible;
    steps = [
      for (final s in from.migration!.steps.reversed) 'Undo: $s',
      if (!from.migration!.reversible)
        'Not declared reversible: plan a fresh migration before demoting.',
    ];
  } else {
    direction = ti > fi ? 'promote' : 'demote';
    if ((ti - fi).abs() > 1) direction = 'jump';
    declared = false;
    reversible = cls == MigrationClass.inPlace;
    steps = [
      for (final c in changes)
        'Move ${c.capability} from ${c.from ?? 'nothing'} to ${c.to ?? 'nothing'}.',
      if (changes.isEmpty) 'Change plan ${from.plan} → ${target.plan}.',
    ];
  }
  final enablesBilling = target.paid && !from.paid;
  return TransitionPlan(
    from: from,
    to: target,
    direction: direction,
    migrationClass: cls,
    reversible: reversible,
    approvalRequired: cls.requiresApproval || i.behavior.mode != Mode.auto,
    enablesBilling: enablesBilling,
    declared: declared,
    bindingChanges: changes,
    steps: [
      if (enablesBilling)
        'Owner: confirm budget ${target.budget?.monthlyUsd ?? '?'} USD/month '
            '(ADR 0003: billing needs owner approval).',
      ...steps,
    ],
  );
}

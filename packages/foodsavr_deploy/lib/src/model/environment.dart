import 'behavior.dart';
import 'identity.dart';

/// Environment names: the app's flavors (`--dart-define=FLAVOR=<name>`).
const flavors = ['development', 'test', 'staging', 'production'];

/// Per-environment tuning of a shared trigger.
class TriggerOverride {
  const TriggerOverride({
    this.warn,
    this.promote,
    this.demote,
    this.enabled = true,
  });

  final double? warn;
  final double? promote;
  final double? demote;
  final bool enabled;
}

/// Per-environment tuning of the shared behavior; null keeps the shared one.
class BehaviorOverride {
  const BehaviorOverride({
    this.pollingInterval,
    this.stabilizationPolls,
    this.minDwell,
    this.mode,
  });

  final Duration? pollingInterval;
  final int? stabilizationPolls;
  final Duration? minDwell;
  final Mode? mode;
}

/// One flavor of the instance, deployed at one level of the shared ladder.
class Environment {
  const Environment({
    required this.name,
    required this.currentLevel,
    this.emulator = false,
    this.githubEnvironment,
    this.firebase,
    this.supabase,
    this.sharedWith = const [],
    this.triggers = const {},
    this.behavior,
  });

  /// One of [flavors].
  final String name;
  final String currentLevel;

  /// Runs against local emulators; needs no cloud identity, is not polled.
  final bool emulator;

  /// GitHub Environment gating deploys/promotions of this environment.
  final String? githubEnvironment;
  final FirebaseIdentity? firebase;
  final SupabaseIdentity? supabase;

  /// Environments whose cloud project this one deliberately reuses; the
  /// first one owns the infrastructure (Terraform).
  final List<String> sharedWith;
  final Map<String, TriggerOverride> triggers;
  final BehaviorOverride? behavior;

  bool get cloud => !emulator;
}

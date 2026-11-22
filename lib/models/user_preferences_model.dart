import 'package:freezed_annotation/freezed_annotation.dart';

import '../constants/preferences_config.dart';
import 'collection_model.dart';

part 'user_preferences_model.freezed.dart';
part 'user_preferences_model.g.dart';

/// Per-account behavior preferences, stored at
/// `users/{uid}/settings/preferences` and synced across devices.
///
/// Every field has a default, so a missing document or a document written by
/// an older client still parses. A group (#197) can later hold a document of
/// the same shape as shared defaults; a member's own document then overrides
/// it key by key (the repository writes with merge semantics).
@freezed
abstract class UserPreferences with _$UserPreferences {
  const UserPreferences._();

  const factory UserPreferences({
    /// Days ahead (1 to [PreferencesConfig.maxExpiringSoonDays]) in which a
    /// product counts as expiring soon.
    @Default(PreferencesConfig.defaultExpiringSoonDays) int expiringSoonDays,

    /// Inventory that receives new products when no collection is given.
    /// Null falls back to the user's first inventory.
    String? defaultInventoryId,
  }) = _UserPreferences;

  factory UserPreferences.fromJson(Map<String, dynamic> json) =>
      _$UserPreferencesFromJson(json);

  /// [expiringSoonDays] limited to the supported range, so a malformed
  /// synced value cannot disable or stretch the window.
  int get effectiveExpiringSoonDays => expiringSoonDays.clamp(
    PreferencesConfig.minExpiringSoonDays,
    PreferencesConfig.maxExpiringSoonDays,
  );

  /// The inventory to use as a default target: [defaultInventoryId] when it
  /// is still one of [inventories], otherwise the first inventory, or null
  /// when there is none.
  String? resolveDefaultInventoryId(List<Collection> inventories) {
    if (inventories.isEmpty) return null;
    final configured = defaultInventoryId;
    if (configured != null && inventories.any((c) => c.id == configured)) {
      return configured;
    }
    return inventories.first.id;
  }
}

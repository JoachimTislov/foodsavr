/// Who an instance is across all its environments.
class Identity {
  const Identity({
    required this.name,
    this.githubRepository,
    required this.region,
  });

  final String name;

  /// `owner/repo` that deploys this instance (Workload Identity condition).
  /// Instance state: set by the overlay (see `loadManifest`), so the tracked
  /// manifest stays fork-neutral.
  final String? githubRepository;

  /// Default region for state buckets and regional resources.
  final String region;
}

/// Firebase project of one environment: the values bootstrap tooling would
/// otherwise hard-code.
class FirebaseIdentity {
  const FirebaseIdentity({
    required this.projectId,
    required this.webAppId,
    this.webApiKeyId,
    String? siteId,
  }) : siteId = siteId ?? projectId;

  final String projectId;
  final String webAppId;

  /// Browser API key id (Terraform imports and restricts it).
  final String? webApiKeyId;

  /// Hosting site; defaults to [projectId].
  final String siteId;
}

/// Spec-ahead (phase 2): Supabase project used by Supabase-bound levels.
class SupabaseIdentity {
  const SupabaseIdentity({required this.projectRef});

  final String projectRef;
}

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../services/barcode_lookup_queue.dart';
import '../../services/sync_status.dart';

/// A slim banner with the number of local changes waiting to sync: writes the
/// server has not acknowledged and barcode lookups queued while offline.
/// Takes no space while everything is in sync.
class PendingSyncBanner extends StatelessWidget {
  final SyncStatus syncStatus;
  final BarcodeLookupQueue lookupQueue;

  const PendingSyncBanner({
    super.key,
    required this.syncStatus,
    required this.lookupQueue,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([syncStatus, lookupQueue]),
      builder: (context, _) {
        final count = syncStatus.pendingWrites + lookupQueue.length;
        if (count == 0) return const SizedBox.shrink();
        final colors = Theme.of(context).colorScheme;
        return Semantics(
          liveRegion: true,
          child: Material(
            color: colors.secondaryContainer,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.cloud_sync_outlined,
                      size: 18,
                      color: colors.onSecondaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'common.pendingChanges'.plural(
                          count,
                          namedArgs: {'count': '$count'},
                        ),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

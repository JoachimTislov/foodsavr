import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../services/barcode_lookup_queue.dart';
import '../../services/sync_status.dart';
import 'dismissible_banner.dart';

/// A slim dismissible banner with the number of local changes waiting to sync:
/// writes the server has not acknowledged and barcode lookups queued while
/// offline. Automatically hides when everything is in sync and resets any
/// previous dismissal once the pending count returns to zero.
class PendingSyncBanner extends StatefulWidget {
  final SyncStatus syncStatus;
  final BarcodeLookupQueue lookupQueue;

  const PendingSyncBanner({
    super.key,
    required this.syncStatus,
    required this.lookupQueue,
  });

  @override
  State<PendingSyncBanner> createState() => _PendingSyncBannerState();
}

class _PendingSyncBannerState extends State<PendingSyncBanner> {
  bool _dismissed = false;

  int get _pendingCount =>
      widget.syncStatus.pendingWrites + widget.lookupQueue.length;

  @override
  void initState() {
    super.initState();
    widget.syncStatus.addListener(_handleSyncChanged);
    widget.lookupQueue.addListener(_handleSyncChanged);
  }

  @override
  void didUpdateWidget(covariant PendingSyncBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.syncStatus != widget.syncStatus) {
      oldWidget.syncStatus.removeListener(_handleSyncChanged);
      widget.syncStatus.addListener(_handleSyncChanged);
    }
    if (oldWidget.lookupQueue != widget.lookupQueue) {
      oldWidget.lookupQueue.removeListener(_handleSyncChanged);
      widget.lookupQueue.addListener(_handleSyncChanged);
    }
    if (_pendingCount == 0 && _dismissed) {
      _dismissed = false;
    }
  }

  @override
  void dispose() {
    widget.syncStatus.removeListener(_handleSyncChanged);
    widget.lookupQueue.removeListener(_handleSyncChanged);
    super.dispose();
  }

  void _handleSyncChanged() {
    if (!mounted) return;
    setState(() {
      if (_pendingCount == 0) {
        _dismissed = false;
      }
    });
  }

  void _dismiss() {
    if (_dismissed) return;
    setState(() {
      _dismissed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final count = _pendingCount;
    final colors = Theme.of(context).colorScheme;

    return DismissibleBanner(
      visible: count > 0 && !_dismissed,
      onDismiss: _dismiss,
      liveRegion: true,
      useTopSafeArea: true,
      backgroundColor: colors.secondaryContainer,
      dismissIconColor: colors.onSecondaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leadingSpacing: 8,
      leading: Icon(
        Icons.cloud_sync_outlined,
        size: 18,
        color: colors.onSecondaryContainer,
      ),
      content: Text(
        'common.pendingChanges'.plural(count, namedArgs: {'count': '$count'}),
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: colors.onSecondaryContainer),
      ),
    );
  }
}

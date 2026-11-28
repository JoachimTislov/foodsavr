import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../constants/adaptive_layout.dart';
import '../interfaces/i_auth_service.dart';
import '../interfaces/i_receipt_repository.dart';
import '../models/receipt_record.dart';
import '../service_locator.dart';
import '../widgets/common/app_breadcrumbs.dart';
import '../widgets/common/content_constraint.dart';
import '../widgets/common/empty_state_widget.dart';
import '../widgets/common/retry_scaffold.dart';
import '../widgets/receipt/receipt_details_sheet.dart';
import '../widgets/receipt/receipt_list_tile.dart';
import 'receipt_scan_view.dart';

/// Every receipt the user registered, newest first.
class ReceiptListView extends StatefulWidget {
  const ReceiptListView({super.key});

  @override
  State<ReceiptListView> createState() => _ReceiptListViewState();
}

class _ReceiptListViewState extends State<ReceiptListView> {
  late final String? _userId = getIt<IAuthService>().getUserId();
  late final IReceiptRepository _receipts = getIt<IReceiptRepository>();

  List<ReceiptRecord> _records = const [];

  Future<void> _load() async {
    final userId = _userId;
    if (userId == null) return;
    final records = await _receipts.list(userId);
    if (mounted) setState(() => _records = records);
  }

  Future<void> _scan() async {
    final userId = _userId;
    if (userId == null) return;
    final ingested = await Navigator.of(context, rootNavigator: true)
        .push<bool>(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => ReceiptScanView(userId: userId),
          ),
        );
    if (ingested == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return RetryScaffold(
      appBar: AppBar(
        title: Text('receipt.listTitle'.tr()),
        automaticallyImplyLeading: !AppBreadcrumbs.handlesBack(context),
      ),
      onRefresh: _load,
      isBodyScrollable: _records.isNotEmpty,
      body: _records.isEmpty
          ? EmptyStateWidget(
              icon: Icons.receipt_long_outlined,
              title: 'receipt.emptyTitle'.tr(),
              subtitle: 'receipt.emptySubtitle'.tr(),
              actions: [
                FilledButton.icon(
                  onPressed: _scan,
                  icon: const Icon(Icons.document_scanner_outlined),
                  label: Text('receipt.scanShort'.tr()),
                ),
              ],
            )
          : ListView(
              children: [
                ContentConstraint(
                  maxWidth: AdaptiveLayout.pageMaxWidth,
                  child: Column(
                    children: [
                      for (final record in _records)
                        ReceiptListTile(
                          record: record,
                          onTap: () =>
                              ReceiptDetailsSheet.show(context, record),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../constants/adaptive_layout.dart';
import '../controllers/batch_expiry_controller.dart';
import '../controllers/preferences_controller.dart';
import '../interfaces/i_auth_service.dart';
import '../service_locator.dart';
import '../services/barcode_scanner_service.dart';
import '../services/collection_service.dart';
import '../services/product_service.dart';
import '../utils/product_add_helper.dart';
import '../utils/user_error.dart';
import '../widgets/common/content_constraint.dart';
import '../widgets/expiry/batch_expiry_step.dart';
import '../widgets/expiry/batch_product_step.dart';
import '../widgets/expiry/registered_expiry_list.dart';

/// Registers expiry dates for many products in one session: scan or pick a
/// product (new or existing), capture its expiry, repeat.
class BatchExpiryView extends StatefulWidget {
  final String? collectionId;

  const BatchExpiryView({super.key, this.collectionId});

  /// Opens the session above the whole app; returns true when anything was
  /// saved.
  static Future<bool?> show(BuildContext context, {String? collectionId}) =>
      Navigator.of(context, rootNavigator: true).push<bool>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => BatchExpiryView(collectionId: collectionId),
        ),
      );

  @override
  State<BatchExpiryView> createState() => _BatchExpiryViewState();
}

class _BatchExpiryViewState extends State<BatchExpiryView> {
  late final BatchExpiryController _controller;
  bool _canScan = false;

  @override
  void initState() {
    super.initState();
    _controller = BatchExpiryController(
      products: getIt<ProductService>(),
      collections: getIt<CollectionService>(),
      preferences: getIt<PreferencesController>(),
      auth: getIt<IAuthService>(),
      collectionId: widget.collectionId,
    );
    _controller.load().catchError(_report);
    BarcodeScannerService.hasCamera().then((value) {
      if (mounted) setState(() => _canScan = value);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _report(Object error, [StackTrace? stack]) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          userErrorMessage(error, 'batchExpiry.saveError'.tr(), stack),
        ),
      ),
    );
  }

  Future<void> _scan() async {
    final languageCode = context.locale.languageCode;
    try {
      final result = await context.push<Object>('/barcode-scan');
      if (!mounted) return;
      await _controller.handleScan(result, languageCode);
    } catch (e, stack) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            userErrorMessage(e, 'batchExpiry.lookupError'.tr(), stack),
          ),
        ),
      );
    }
  }

  Future<void> _pickDate() async {
    final date = await ProductAddHelper.captureExpiryDate(context);
    if (date != null) _controller.setDate(date);
  }

  Future<void> _save() async {
    try {
      await _controller.save();
    } catch (e, stack) {
      _report(e, stack);
    }
  }

  void _done() => Navigator.of(context).pop(_controller.registered.isNotEmpty);

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _done();
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text('batchExpiry.title'.tr()),
        actions: [
          TextButton(onPressed: _done, child: Text('batchExpiry.done'.tr())),
        ],
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ContentConstraint(
            maxWidth: AdaptiveLayout.detailMaxWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_controller.hasProduct)
                  BatchExpiryStep(
                    controller: _controller,
                    onPickDate: _pickDate,
                    onSave: _save,
                  )
                else
                  BatchProductStep(
                    controller: _controller,
                    onScan: _canScan ? _scan : null,
                  ),
                const SizedBox(height: 24),
                RegisteredExpiryList(items: _controller.registered),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

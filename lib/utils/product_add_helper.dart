import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../controllers/preferences_controller.dart';
import '../interfaces/i_auth_service.dart';
import '../models/product_model.dart';
import '../service_locator.dart';
import '../services/barcode_scanner_service.dart';
import '../services/open_food_facts_client.dart';
import '../services/product_service.dart';
import '../services/collection_service.dart';
import '../views/expiry_scan_view.dart';
import '../views/product_form_view.dart';
import '../views/product_detail_view.dart';
import 'expiry_date_picker.dart';
import 'localization.dart';
import 'user_error.dart';

enum BarcodeScanAction { addWithoutBarcode, expiryFirst }

class ProductAddHelper {
  /// Starts with the barcode scanner where the camera can scan, and otherwise
  /// opens the Add Product modal with its barcode and name lookup.
  static Future<bool?> startAddProductFlow(
    BuildContext context, {
    String? collectionId,
  }) async {
    final canScan = await BarcodeScannerService.hasCamera();
    if (!context.mounted) return false;
    if (!canScan) {
      return ProductFormView.show(context, collectionId: collectionId);
    }
    final result = await context.push<Object>('/barcode-scan');
    if (!context.mounted) return false;
    return finishAddProductFlow(context, result, collectionId: collectionId);
  }

  /// Captures the expiry date first, by scanning it where the camera can and
  /// with the date picker otherwise, then asks for the rest of the product.
  static Future<bool?> startExpiryFirstFlow(
    BuildContext context, {
    String? collectionId,
  }) async {
    final canScan = await BarcodeScannerService.hasCamera();
    if (!context.mounted) return false;
    final date = canScan
        ? await ExpiryScanView.show(context)
        : await pickExpiryDate(context);
    if (date == null || !context.mounted) return false;
    final userId = getIt<IAuthService>().getUserId();
    if (userId == null) return false;
    return ProductFormView.show(
      context,
      prefill: Product(
        id: '',
        name: '',
        description: '',
        userId: userId,
        expiries: [ExpiryEntry(quantity: 1, expirationDate: date)],
      ),
      collectionId: collectionId,
    );
  }

  /// Completes the flow with what the scanner returned: a barcode, a chosen
  /// [OffProductData] candidate, or a [BarcodeScanAction].
  static Future<bool?> finishAddProductFlow(
    BuildContext context,
    Object? result, {
    String? collectionId,
  }) async {
    if (result == BarcodeScanAction.addWithoutBarcode) {
      return await ProductFormView.show(context, collectionId: collectionId);
    }
    if (result == BarcodeScanAction.expiryFirst) {
      return await startExpiryFirstFlow(context, collectionId: collectionId);
    }
    if (result is OffProductData) {
      return await ProductFormView.show(
        context,
        candidate: result,
        collectionId: collectionId,
      );
    }
    if (result is! String || result.isEmpty) return false;

    collectionId ??= await getIt<PreferencesController>()
        .resolveDefaultInventoryId();
    if (!context.mounted) return false;

    final authService = getIt<IAuthService>();
    final productService = getIt<ProductService>();
    final collectionService = getIt<CollectionService>();
    final userId = authService.getUserId();
    if (userId == null) return false;

    final messenger = ScaffoldMessenger.of(context);
    var loadingOpen = false;
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      loadingOpen = true;

      final addResult = await productService.addOrIncrementByBarcode(
        userId: userId,
        barcode: result,
        languageCode: context.locale.languageCode,
      );

      if (!context.mounted) return false;
      Navigator.of(
        context,
        rootNavigator: true,
      ).pop(); // Dismiss loading indicator
      loadingOpen = false;

      if (addResult.notFound) {
        messenger.showSnackBar(
          SnackBar(content: Text('product.barcodeNotFound'.tr())),
        );
        return await ProductFormView.show(
          context,
          prefill: addResult.product,
          collectionId: collectionId,
        );
      } else {
        if (collectionId != null) {
          // The scan already saved the product; a failed assignment is
          // reported without failing (and so repeating) the scan.
          try {
            await collectionService.addProductToCollection(
              collectionId,
              addResult.product.id,
            );
          } catch (e) {
            messenger.showSnackBar(
              SnackBar(
                content: Text(
                  'product.addToInventoryError'.tr(namedArgs: {'error': '$e'}),
                ),
              ),
            );
          }
        }

        if (!context.mounted) return false;

        final expiryDays = addResult.estimatedExpiryDays;
        final expiryMsg = 'product.barcodeAssumedExpiry'.trWith(
          namedArgs: {'days': '$expiryDays'},
          when: expiryDays != null,
        );

        messenger.showSnackBar(
          SnackBar(
            content: Text(
              addResult.offline
                  ? 'product.barcodeOffline'.tr()
                  : (addResult.matchedExisting
                            ? 'product.barcodeMatched'.tr(
                                namedArgs: {'name': addResult.product.name},
                              )
                            : 'product.barcodeCreated'.tr(
                                namedArgs: {'name': addResult.product.name},
                              )) +
                        expiryMsg,
            ),
          ),
        );

        // Show the product after adding it
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ProductDetailView(product: addResult.product),
          ),
        );

        return true;
      }
    } catch (e, stack) {
      if (!context.mounted) return false;
      if (loadingOpen) {
        Navigator.of(
          context,
          rootNavigator: true,
        ).pop(); // Dismiss loading indicator
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            userErrorMessage(e, 'product.barcodeAddError'.tr(), stack),
          ),
        ),
      );
      return false;
    }
  }
}

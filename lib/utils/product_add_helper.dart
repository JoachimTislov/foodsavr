import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../interfaces/i_auth_service.dart';
import '../service_locator.dart';
import '../services/product_service.dart';
import '../services/collection_service.dart';
import '../views/product_form_view.dart';
import '../views/product_detail_view.dart';

class ProductAddHelper {
  static Future<bool?> startAddProductFlow(
    BuildContext context, {
    String? collectionId,
  }) async {
    final scannedBarcode = await context.push<String>('/barcode-scan');

    if (!context.mounted || scannedBarcode == null || scannedBarcode.isEmpty) {
      return false;
    }

    if (scannedBarcode == 'MANUAL_ENTRY') {
      return await ProductFormView.show(context, collectionId: collectionId);
    }

    final authService = getIt<IAuthService>();
    final productService = getIt<ProductService>();
    final collectionService = getIt<CollectionService>();
    final userId = authService.getUserId();
    if (userId == null) return false;

    final messenger = ScaffoldMessenger.of(context);
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final result = await productService.addOrIncrementByBarcode(
        userId: userId,
        barcode: scannedBarcode,
        languageCode: context.locale.languageCode,
      );

      if (!context.mounted) return false;
      Navigator.of(
        context,
        rootNavigator: true,
      ).pop(); // Dismiss loading indicator

      if (result.notFound) {
        messenger.showSnackBar(
          SnackBar(content: Text('product.barcodeNotFound'.tr())),
        );
        return await ProductFormView.show(
          context,
          product: result.product,
          collectionId: collectionId,
        );
      } else {
        if (collectionId != null) {
          await collectionService.addProductToCollection(
            collectionId,
            result.product.id,
          );
        }

        if (!context.mounted) return false;

        final expiryDays = result.estimatedExpiryDays;
        final expiryMsg = expiryDays != null
            ? 'product.barcodeAssumedExpiry'.tr(
                namedArgs: {'days': expiryDays.toString()},
              )
            : '';

        messenger.showSnackBar(
          SnackBar(
            content: Text(
              (result.matchedExisting
                      ? 'product.barcodeMatched'.tr(
                          namedArgs: {'name': result.product.name},
                        )
                      : 'product.barcodeCreated'.tr(
                          namedArgs: {'name': result.product.name},
                        )) +
                  expiryMsg,
            ),
          ),
        );

        // Show the product after adding it
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ProductDetailView(product: result.product),
          ),
        );

        return true;
      }
    } catch (e) {
      if (!context.mounted) return false;
      Navigator.of(
        context,
        rootNavigator: true,
      ).pop(); // Dismiss loading indicator
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'product.barcodeAddError'.tr(namedArgs: {'error': '$e'}),
          ),
        ),
      );
      return false;
    }
  }
}

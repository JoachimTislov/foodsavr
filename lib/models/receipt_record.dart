import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:receipt_recognition/receipt_recognition.dart';

/// Idempotency record of one ingested receipt: a raw event of source
/// `receipt` in the ADR 0005 inbox, keyed `receipt:<store>:<hash>`.
class ReceiptRecord {
  const ReceiptRecord({
    required this.id,
    required this.provider,
    required this.externalId,
    required this.occurredAt,
    required this.itemCount,
    required this.productIds,
    this.store,
    this.purchaseDate,
    this.collectionId,
  });

  /// Raw-event idempotency key: `receipt:<provider>:<externalId>`.
  final String id;

  /// Slug of the recognized store; null when none was recognized (written as
  /// `app` in [id]).
  final String? provider;

  /// Hash of the receipt fingerprint.
  final String externalId;

  /// Purchase date when recognized, else the time of ingestion.
  final DateTime occurredAt;
  final String? store;
  final DateTime? purchaseDate;
  final String? collectionId;
  final int itemCount;
  final List<String> productIds;

  /// Builds the record for [receipt] after its items were saved.
  factory ReceiptRecord.from(
    RecognizedReceipt receipt, {
    required List<String> productIds,
    String? collectionId,
    DateTime? now,
  }) {
    final provider = _slug(receipt.store?.value);
    final externalId = _hash(receipt.fingerprint);
    final purchaseDate = receipt.purchaseDate?.value;
    return ReceiptRecord(
      id: 'receipt:${provider ?? 'app'}:$externalId',
      provider: provider,
      externalId: externalId,
      occurredAt: purchaseDate ?? now ?? DateTime.now(),
      store: receipt.store?.value,
      purchaseDate: purchaseDate,
      collectionId: collectionId,
      itemCount: productIds.length,
      productIds: productIds,
    );
  }

  /// The idempotency key of [receipt] without building a full record.
  static String idFor(RecognizedReceipt receipt) =>
      ReceiptRecord.from(receipt, productIds: const []).id;

  /// Source-specific payload of the raw event.
  Map<String, Object?> get payload => {
    'store': store,
    'purchaseDate': purchaseDate?.toIso8601String(),
    'itemCount': itemCount,
    'collectionId': collectionId,
    'productIds': productIds,
  };

  static String _hash(String fingerprint) =>
      sha256.convert(utf8.encode(fingerprint)).toString().substring(0, 32);

  static String? _slug(String? store) {
    final slug = store
        ?.toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return slug == null || slug.isEmpty ? null : slug;
  }
}

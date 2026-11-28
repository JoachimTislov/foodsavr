import 'dart:convert';
import 'dart:typed_data';

import 'package:injectable/injectable.dart';

import '../models/collection_model.dart';
import '../models/product_model.dart';
import '../utils/collection_types.dart';
import 'collection_service.dart';
import 'data_export_service_stub.dart'
    if (dart.library.js_interop) 'data_export_service_web.dart';
import 'product_service.dart';

/// File formats of a data export; [csv] is the default.
enum ExportFormat {
  csv('csv', 'text/csv;charset=utf-8'),
  json('json', 'application/json;charset=utf-8');

  const ExportFormat(this.extension, this.mimeType);

  final String extension;
  final String mimeType;
}

/// What to export: the chosen inventories and shopping lists, and whether the
/// user's products catalog is included. Pass no selection to export all.
class ExportSelection {
  const ExportSelection({
    this.collectionIds = const {},
    this.includeProducts = false,
  });

  final Set<String> collectionIds;
  final bool includeProducts;

  bool get isEmpty => collectionIds.isEmpty && !includeProducts;
}

/// A generated export, ready to be saved.
class ExportFile {
  const ExportFile({
    required this.fileName,
    required this.format,
    required this.content,
  });

  final String fileName;
  final ExportFormat format;
  final String content;

  Uint8List get bytes => utf8.encode(content);
}

/// Saves [file] outside the app. Returns false when the platform cannot.
typedef ExportSink = Future<bool> Function(ExportFile file);

Future<bool> _downloadSink(ExportFile file) =>
    downloadExportFile(file.fileName, file.format.mimeType, file.bytes);

/// Builds CSV and JSON exports of the user's collections and products.
///
/// Reads only: unlike opening a collection, exporting never repairs dangling
/// product IDs.
@lazySingleton
class DataExportService {
  DataExportService(
    this._collectionService,
    this._productService, {
    @ignoreParam ExportSink? sink,
    @ignoreParam DateTime Function()? clock,
  }) : _sink = sink ?? _downloadSink,
       _clock = clock ?? DateTime.now;

  static const csvColumns = [
    'section',
    'collection_name',
    'collection_type',
    'product_name',
    'category',
    'barcode',
    'quantity',
    'expiration_date',
    'notes',
  ];

  /// Marks the CSV as UTF-8, so spreadsheet apps read non-ASCII letters.
  static const byteOrderMark = '\uFEFF';

  final CollectionService _collectionService;
  final ProductService _productService;
  final ExportSink _sink;
  final DateTime Function() _clock;

  /// The inventories and shopping lists of [userId] that can be exported.
  Future<List<Collection>> loadCollections(String userId) =>
      _collectionService.getCollectionsForUser(userId);

  /// Builds the export and hands it to the sink. [delivered] is false when
  /// this platform has no way to save the file.
  Future<({ExportFile file, bool delivered})> export({
    required String userId,
    ExportSelection? selection,
    ExportFormat format = ExportFormat.csv,
  }) async {
    final file = await build(
      userId: userId,
      selection: selection,
      format: format,
    );
    return (file: file, delivered: await _sink(file));
  }

  /// Builds the export of [selection], or of everything when it is null.
  ///
  /// Throws a [StateError] when a selected collection no longer exists, so an
  /// export never silently leaves out something the user asked for.
  Future<ExportFile> build({
    required String userId,
    ExportSelection? selection,
    ExportFormat format = ExportFormat.csv,
  }) async {
    if (selection != null && selection.isEmpty) {
      throw ArgumentError.value(selection, 'selection', 'Nothing selected');
    }
    final all = await loadCollections(userId);
    final collections = selection == null
        ? all
        : all.where((c) => selection.collectionIds.contains(c.id)).toList();
    if (selection != null &&
        collections.length != selection.collectionIds.length) {
      throw StateError('A selected collection no longer exists.');
    }

    final current = await _productService.getProducts(
      userId,
      forceRefresh: true,
    );
    final saved = await _productService.getPersonalProducts(userId);
    final byId = {
      for (final product in [...current, ...saved]) product.id: product,
    };
    final members = [
      for (final collection in collections)
        (
          collection: collection,
          products: [for (final id in collection.productIds.toSet()) ?byId[id]],
        ),
    ];
    final includeProducts = selection?.includeProducts ?? true;
    final now = _clock();

    return ExportFile(
      fileName: 'foodsavr-export-${_date(now)}.${format.extension}',
      format: format,
      content: switch (format) {
        ExportFormat.csv => _csv(
          members,
          includeProducts ? current : const [],
          includeProducts ? saved : const [],
        ),
        ExportFormat.json => _json(
          now,
          members,
          includeProducts ? current : null,
          includeProducts ? saved : null,
        ),
      },
    );
  }

  String _csv(
    List<({Collection collection, List<Product> products})> members,
    List<Product> current,
    List<Product> saved,
  ) {
    final rows = <List<String>>[
      csvColumns,
      for (final (:collection, :products) in members) ...[
        // An empty collection keeps one row, so it is not lost.
        if (products.isEmpty)
          [
            _section(collection.type),
            collection.name,
            collection.type.name,
            for (var i = 3; i < csvColumns.length; i++) '',
          ],
        for (final product in products)
          ..._productRows(
            _section(collection.type),
            collection.name,
            collection.type.name,
            product,
          ),
      ],
      for (final product in current)
        ..._productRows('products', '', 'products', product),
      for (final product in saved)
        ..._productRows('saved_products', '', 'products', product),
    ];
    return '$byteOrderMark${rows.map(_csvLine).join()}';
  }

  /// One row per expiry date, plus one for the quantity without a date.
  List<List<String>> _productRows(
    String section,
    String collectionName,
    String collectionType,
    Product product,
  ) {
    List<String> row(int quantity, String expirationDate) => [
      section,
      collectionName,
      collectionType,
      product.name,
      product.category ?? '',
      product.barcode ?? '',
      '$quantity',
      expirationDate,
      product.description,
    ];
    return [
      for (final entry in product.expiries)
        row(entry.quantity, _date(entry.expirationDate)),
      if (product.expiries.isEmpty || product.nonExpiringQuantity > 0)
        row(product.nonExpiringQuantity, ''),
    ];
  }

  static String _section(CollectionType type) => switch (type) {
    CollectionType.inventory => 'inventory',
    CollectionType.shoppingList => 'shopping_list',
  };

  /// An RFC 4180 record, including its CRLF line break.
  static String _csvLine(List<String> fields) =>
      '${fields.map(escapeCsvField).join(',')}\r\n';

  static final _needsQuotes = RegExp('[",\r\n]|^ | \$');
  static final _formulaStart = RegExp('^[=+\\-@\t\r]');
  static final _number = RegExp(r'^-?\d+([.,]\d+)?$');

  /// Quotes [value] as RFC 4180 requires. Text that a spreadsheet would run as
  /// a formula is prefixed with an apostrophe; JSON keeps the exact value.
  static String escapeCsvField(String value) {
    final safe = _formulaStart.hasMatch(value) && !_number.hasMatch(value)
        ? "'$value"
        : value;
    return _needsQuotes.hasMatch(safe)
        ? '"${safe.replaceAll('"', '""')}"'
        : safe;
  }

  String _json(
    DateTime exportedAt,
    List<({Collection collection, List<Product> products})> members,
    List<Product>? current,
    List<Product>? saved,
  ) {
    Map<String, Object?> product(Product value) =>
        value.toJson()..remove('userId');
    return const JsonEncoder.withIndent('  ').convert({
      'application': 'foodsavr',
      'formatVersion': 1,
      'exportedAt': exportedAt.toUtc().toIso8601String(),
      'collections': [
        for (final (:collection, :products) in members)
          {
            'id': collection.id,
            'name': collection.name,
            'type': collection.type.name,
            'description': collection.description,
            'products': products.map(product).toList(),
          },
      ],
      if (current != null) 'products': current.map(product).toList(),
      if (saved != null) 'savedProducts': saved.map(product).toList(),
    });
  }

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

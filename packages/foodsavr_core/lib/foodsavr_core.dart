/// Shared FoodSavr domain logic.
///
/// Normalizes arbitrary food inputs (receipts, grocery-API orders, recipes,
/// barcodes, free text) into a unified [LineItem] format, then runs fuzzy
/// matching, shelf-life inference, and confidence-based confirmation.
///
/// This package is pure Dart on purpose: the Flutter app and the planned MCP
/// server both consume it, so it must not depend on Flutter or Firebase.
library;

export 'src/confidence_gate.dart';
export 'src/line_item.dart';
export 'src/matcher.dart';
export 'src/normalizer.dart';
export 'src/pipeline.dart';
export 'src/shelf_life.dart';

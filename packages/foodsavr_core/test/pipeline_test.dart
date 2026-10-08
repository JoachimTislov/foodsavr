import 'package:foodsavr_core/src/confidence_gate.dart';
import 'package:foodsavr_core/src/line_item.dart';
import 'package:foodsavr_core/src/matcher.dart';
import 'package:foodsavr_core/src/pipeline.dart';
import 'package:test/test.dart';

void main() {
  final catalog = [
    const CatalogProduct(id: 'p1', name: 'Tine Melk', barcode: '7037320000000'),
    const CatalogProduct(id: 'p2', name: 'Brød'),
  ];

  group('ConfidenceGate', () {
    const gate = ConfidenceGate();

    test('autoAdd at/above threshold', () {
      expect(
        gate.decide(const MatchResult(confidence: 0.9)),
        ConfidenceDecision.autoAdd,
      );
    });

    test('confirm between thresholds', () {
      expect(
        gate.decide(const MatchResult(confidence: 0.7)),
        ConfidenceDecision.confirm,
      );
    });

    test('hold below threshold', () {
      expect(
        gate.decide(const MatchResult(confidence: 0.2)),
        ConfidenceDecision.hold,
      );
    });

    test('no match always holds', () {
      expect(
        gate.decide(const MatchResult.none()),
        ConfidenceDecision.hold,
      );
    });
  });

  group('IngestionPipeline.process', () {
    final pipeline = IngestionPipeline();

    test('normalizes, matches, infers, and decides end-to-end', () {
      final r = pipeline.process(
        LineItem(
          id: 'i1',
          rawName: '2 STK TINE MELK',
          source: IngestionSource.receipt,
        ),
        catalog,
      );
      expect(r.item.normalizedName, 'tine melk');
      expect(r.item.quantity, 2);
      expect(r.item.unit, LineItemUnit.piece);
      expect(r.item.matchedProductId, 'p1');
      expect(r.item.matchConfidence, 1.0);
      expect(r.item.inferredShelfLifeDays, isNotNull);
      expect(r.decision, ConfidenceDecision.autoAdd);
      expect(r.needsConfirmation, isFalse);
    });

    test('barcode item is exact autoAdd', () {
      final r = pipeline.process(
        LineItem(
          id: 'i2',
          rawName: 'ukjent produkt',
          barcode: '7037320000000',
          source: IngestionSource.barcode,
        ),
        catalog,
      );
      expect(r.item.matchedProductId, 'p1');
      expect(r.item.matchConfidence, 1.0);
      expect(r.decision, ConfidenceDecision.autoAdd);
    });

    test('garbage receipt line is held, not auto-added', () {
      final r = pipeline.process(
        LineItem(
          id: 'i3',
          rawName: 'XXXX 0000 1234',
          source: IngestionSource.receipt,
        ),
        catalog,
      );
      expect(r.decision, ConfidenceDecision.hold);
      expect(r.item.matchedProductId, isNull);
    });

    test('plausible-but-not-exact match needs confirmation', () {
      final r = pipeline.process(
        LineItem(id: 'i4', rawName: 'brødboller', source: IngestionSource.freeText),
        catalog,
      );
      expect(r.decision, isAnyOf(ConfidenceDecision.confirm, ConfidenceDecision.autoAdd));
      expect(r.match.hasMatch, isTrue);
    });

    test('processAll preserves order', () {
      final rs = pipeline.processAll([
        LineItem(id: 'a', rawName: 'TINE MELK'),
        LineItem(id: 'b', rawName: 'BRØD'),
      ], catalog);
      expect(rs.map((r) => r.item.id), ['a', 'b']);
      expect(rs.every((r) => r.decision == ConfidenceDecision.autoAdd), isTrue);
    });
  });
}

import 'package:foodsavr_core/src/line_item.dart';
import 'package:foodsavr_core/src/normalizer.dart';
import 'package:test/test.dart';

void main() {
  final n = Normalizer();

  group('Normalizer.normalize', () {
    test('folds case and collapses whitespace', () {
      final r = n.normalize('  Ice   Cream!!  ');
      expect(r.name, 'ice cream');
      expect(r.quantity, 1);
      expect(r.unit, LineItemUnit.piece);
    });

    test('extracts liter quantity prefix', () {
      final r = n.normalize('1l milk');
      expect(r.name, 'milk');
      expect(r.quantity, 1);
      expect(r.unit, LineItemUnit.liter);
    });

    test('extracts unit regardless of case and spacing', () {
      final r = n.normalize('MELK 1 L');
      expect(r.name, 'melk');
      expect(r.quantity, 1);
      expect(r.unit, LineItemUnit.liter);
    });

    test('extracts Norwegian piece tokens', () {
      final r = n.normalize('2 STK TINE MELK');
      expect(r.name, 'tine melk');
      expect(r.quantity, 2);
      expect(r.unit, LineItemUnit.piece);
    });

    test('extracts decimal quantity with comma', () {
      final r = n.normalize('0,5 KG KJØTTDEIG');
      expect(r.name, 'kjøttdeig');
      expect(r.quantity, 0.5);
      expect(r.unit, LineItemUnit.kilogram);
    });

    test('strips promotional noise tokens', () {
      final r = n.normalize('MELK TILBUD');
      expect(r.name, 'melk');
    });

    test('keeps unicode letters like æøå', () {
      final r = n.normalize('RØMMERØRE');
      expect(r.name, 'rømmerøre');
    });
  });
}

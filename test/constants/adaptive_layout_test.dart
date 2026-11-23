import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/constants/adaptive_layout.dart';

void main() {
  test('WindowSize.fromWidth follows the Material 3 breakpoints', () {
    expect(WindowSize.fromWidth(320), WindowSize.compact);
    expect(WindowSize.fromWidth(599.9), WindowSize.compact);
    expect(WindowSize.fromWidth(600), WindowSize.medium);
    expect(WindowSize.fromWidth(839.9), WindowSize.medium);
    expect(WindowSize.fromWidth(840), WindowSize.expanded);
    expect(WindowSize.fromWidth(1920), WindowSize.expanded);
  });

  test('gutterFor splits the space beyond the maximum width', () {
    expect(AdaptiveLayout.gutterFor(500, 960), 0);
    expect(AdaptiveLayout.gutterFor(960, 960), 0);
    expect(AdaptiveLayout.gutterFor(1200, 960), 120);
  });
}

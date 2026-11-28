import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/routes/page_trail.dart';

void main() {
  late PageTrail trail;
  late GlobalKey<NavigatorState> navigatorKey;

  setUp(() {
    trail = PageTrail();
    navigatorKey = GlobalKey<NavigatorState>();
  });

  Future<void> pump(WidgetTester tester) async {
    // A page-based root, as under GoRouter, is never tracked.
    await tester.pumpWidget(
      MaterialApp(
        home: Navigator(
          key: navigatorKey,
          observers: [trail],
          pages: const [MaterialPage<void>(child: Text('root'))],
          onDidRemovePage: (_) {},
        ),
      ),
    );
  }

  BuildContext context() => navigatorKey.currentContext!;

  Future<void> push(WidgetTester tester, String label) async {
    PageTrail.push<void>(
      context(),
      label: label,
      builder: (_) => Text('$label page'),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('tracks named pushed pages and notifies listeners', (
    tester,
  ) async {
    await pump(tester);
    var notifications = 0;
    trail.addListener(() => notifications++);

    await push(tester, 'Pantry');
    await push(tester, 'Milk');

    expect(trail.routes.map((r) => r.settings.name), ['Pantry', 'Milk']);
    expect(notifications, greaterThan(0));
  });

  testWidgets('ignores unnamed and dialog routes', (tester) async {
    await pump(tester);

    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const Text('unnamed')),
    );
    await tester.pumpAndSettle();
    showDialog<void>(
      context: context(),
      routeSettings: const RouteSettings(name: 'dialog'),
      builder: (_) => const AlertDialog(title: Text('dialog')),
    );
    await tester.pumpAndSettle();

    expect(trail.routes, isEmpty);
  });

  testWidgets('a pop removes the page from the trail', (tester) async {
    await pump(tester);
    await push(tester, 'Pantry');
    await push(tester, 'Milk');

    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();

    expect(trail.routes.map((r) => r.settings.name), ['Pantry']);
    expect(find.text('Pantry page'), findsOneWidget);
  });

  testWidgets('popTo a route pops the pages above it', (tester) async {
    await pump(tester);
    await push(tester, 'Pantry');
    await push(tester, 'Milk');
    await push(tester, 'Batch');

    trail.popTo(trail.routes.first);
    await tester.pumpAndSettle();

    expect(trail.routes.map((r) => r.settings.name), ['Pantry']);
    expect(find.text('Pantry page'), findsOneWidget);
  });

  testWidgets('popTo null pops every tracked page', (tester) async {
    await pump(tester);
    await push(tester, 'Pantry');
    await push(tester, 'Milk');

    trail.popTo(null);
    await tester.pumpAndSettle();

    expect(trail.routes, isEmpty);
    expect(find.text('root'), findsOneWidget);
  });

  test('keeps one trail per branch', () {
    expect(PageTrail.branches, hasLength(PageTrail.branchCount));
  });
}

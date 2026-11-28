import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/constants/legal_docs.dart';
import 'package:foodsavr/constants/public_routes.dart';
import 'package:foodsavr/controllers/user_controller.dart';
import 'package:foodsavr/views/delete_account_view.dart';
import 'package:foodsavr/views/legal_document_view.dart';
import 'package:foodsavr/widgets/common/url_modal_dialog.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockUserController extends Mock implements UserController {}

Widget _localizedApp(GoRouter router) {
  return EasyLocalization(
    supportedLocales: const [Locale('en'), Locale('nb')],
    path: 'assets/translations',
    fallbackLocale: const Locale('en'),
    child: Builder(
      builder: (context) => MaterialApp.router(
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        routerConfig: router,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  EasyLocalization.logger.enableBuildModes = [];
  EasyLocalization.logger.enableLevels = [];

  setUp(() async {
    GoRouter.optionURLReflectsImperativeAPIs = true;
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  group('ModalDialogPage and UrlModalDialog', () {
    testWidgets(
      'renders pushed legal modal as a small centered dialog over underlying screen',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final router = GoRouter(
          initialLocation: '/settings',
          routes: [
            GoRoute(
              path: '/settings',
              builder: (context, _) => Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () => context.push(PublicRoutes.terms),
                    child: const Text('Open Terms'),
                  ),
                ),
              ),
            ),
            GoRoute(
              path: PublicRoutes.terms,
              pageBuilder: (_, state) => ModalDialogPage<void>(
                key: state.pageKey,
                name: state.matchedLocation,
                child: const LegalDocumentView(document: LegalDoc.terms),
              ),
            ),
            GoRoute(
              path: PublicRoutes.privacy,
              pageBuilder: (_, state) => ModalDialogPage<void>(
                key: state.pageKey,
                name: state.matchedLocation,
                child: const LegalDocumentView(document: LegalDoc.privacy),
              ),
            ),
            GoRoute(
              path: PublicRoutes.deleteAccount,
              pageBuilder: (_, state) => ModalDialogPage<void>(
                key: state.pageKey,
                name: state.matchedLocation,
                child: const UrlModalDialog(
                  title: 'Delete Account',
                  icon: Icons.delete_outline,
                  child: Text('Delete body'),
                ),
              ),
            ),
          ],
        );
        addTearDown(router.dispose);

        await tester.runAsync(() async {
          await tester.pumpWidget(_localizedApp(router));
          await tester.pumpAndSettle();

          await tester.tap(find.text('Open Terms'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          expect(find.byType(LegalDocumentView), findsOneWidget);
          expect(find.byType(Dialog), findsOneWidget);
          // Underlying screen stays mounted behind the translucent dialog route.
          expect(find.text('Open Terms'), findsOneWidget);

          // Small centered modal width is capped near 460px, not full-width.
          final dialogMaterial = find
              .descendant(
                of: find.byType(Dialog),
                matching: find.byType(Material),
              )
              .first;
          final modalSize = tester.getSize(dialogMaterial);
          expect(modalSize.width, lessThanOrEqualTo(UrlModalDialog.maxWidth));
          expect(modalSize.width, greaterThan(300));

          // Switch modals via footer link without losing the underlying route.
          await tester.tap(find.text('Privacy Notice'));
          await tester.pumpAndSettle();
          expect(
            router.routeInformationProvider.value.uri.path,
            PublicRoutes.privacy,
          );

          // Dismissing via Close returns directly to /settings.
          await tester.tap(find.byKey(const Key('url_modal_close_icon')));
          await tester.pumpAndSettle();
          expect(router.routeInformationProvider.value.uri.path, '/settings');
          expect(find.byType(LegalDocumentView), findsNothing);
        });
      },
    );

    testWidgets(
      'renders standalone cold-loaded legal modal over themed backdrop and closes to fallback route',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final router = GoRouter(
          initialLocation: PublicRoutes.privacy,
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => const Scaffold(body: Text('Home Screen')),
            ),
            GoRoute(
              path: PublicRoutes.privacy,
              pageBuilder: (_, state) => ModalDialogPage<void>(
                key: state.pageKey,
                name: state.matchedLocation,
                child: const LegalDocumentView(document: LegalDoc.privacy),
              ),
            ),
          ],
        );
        addTearDown(router.dispose);

        await tester.runAsync(() async {
          await tester.pumpWidget(_localizedApp(router));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          expect(find.byType(LegalDocumentView), findsOneWidget);
          expect(
            find.byKey(const Key('url_modal_standalone_scrim')),
            findsOneWidget,
          );
          expect(
            find.textContaining(LegalDocs.contactEmail, findRichText: true),
            findsOneWidget,
          );

          final dialogMaterial = find
              .descendant(
                of: find.byType(Dialog),
                matching: find.byType(Material),
              )
              .first;
          expect(
            tester.getSize(dialogMaterial).width,
            lessThanOrEqualTo(UrlModalDialog.maxWidth),
          );

          await tester.tap(find.byKey(const Key('url_modal_close_icon')));
          await tester.pumpAndSettle();
          expect(router.routeInformationProvider.value.uri.path, '/');
          expect(find.text('Home Screen'), findsOneWidget);
        });
      },
    );

    testWidgets(
      'renders DeleteAccountView inside small URL modal on cold load',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final controller = _MockUserController();
        when(() => controller.isInitialized).thenReturn(true);
        when(() => controller.user).thenReturn(null);
        when(
          () => controller.deletionRequiresReauthentication,
        ).thenReturn(false);
        when(() => controller.deletionRequiresPassword).thenReturn(false);
        when(() => controller.isLoading).thenReturn(false);
        when(() => controller.errorMessage).thenReturn(null);

        final router = GoRouter(
          initialLocation: PublicRoutes.deleteAccount,
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => const Scaffold(body: Text('Home Screen')),
            ),
            GoRoute(
              path: PublicRoutes.deleteAccount,
              pageBuilder: (_, state) => ModalDialogPage<void>(
                key: state.pageKey,
                name: state.matchedLocation,
                child: DeleteAccountView(controller: controller),
              ),
            ),
          ],
        );
        addTearDown(router.dispose);

        await tester.runAsync(() async {
          await tester.pumpWidget(_localizedApp(router));
          await tester.pumpAndSettle();

          expect(find.byType(DeleteAccountView), findsOneWidget);
          expect(
            find.text('Sign in to the account you want to delete.'),
            findsOneWidget,
          );

          final dialogMaterial = find
              .descendant(
                of: find.byType(Dialog),
                matching: find.byType(Material),
              )
              .first;
          expect(
            tester.getSize(dialogMaterial).width,
            lessThanOrEqualTo(UrlModalDialog.maxWidth),
          );

          // Tapping outside the modal card dismisses standalone modal to '/'.
          await tester.tapAt(const Offset(16, 16));
          await tester.pumpAndSettle();
          expect(router.routeInformationProvider.value.uri.path, '/');
          expect(find.text('Home Screen'), findsOneWidget);
        });
      },
    );
  });
}

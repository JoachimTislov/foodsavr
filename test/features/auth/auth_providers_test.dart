import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/features/auth/auth_providers.dart';
import 'package:foodsavr/interfaces/i_auth_service.dart';
import 'package:foodsavr/service_locator.dart';
import 'package:logger/logger.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthService extends Mock implements IAuthService {}

class _MockUserCredential extends Mock implements UserCredential {}

void main() {
  late _MockAuthService authService;

  setUp(() async {
    await getIt.reset();
    authService = _MockAuthService();
    getIt.registerLazySingleton<IAuthService>(() => authService);
    getIt.registerLazySingleton<Logger>(() => Logger(level: Level.off));
  });

  tearDown(() async {
    await getIt.reset();
  });

  test('authControllerProvider authenticates via registered auth service', () async {
    when(
      () => authService.signIn(
        email: 'user@example.com',
        password: 'password123',
        rememberMe: any(named: 'rememberMe'),
      ),
    ).thenAnswer((_) async => _MockUserCredential());

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(authControllerProvider);

    await controller.authenticate(
      email: 'user@example.com',
      password: 'password123',
    );

    verify(
      () => authService.signIn(
        email: 'user@example.com',
        password: 'password123',
        rememberMe: false,
      ),
    ).called(1);
  });
}

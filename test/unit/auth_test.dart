import 'package:flutter_test/flutter_test.dart';
import 'package:agecare_app/core/network/api_client.dart';
import 'package:agecare_app/features/auth/data/auth_repository.dart';
import 'package:agecare_app/features/auth/domain/models.dart';

void main() {
  group('AuthRepository Unit Tests', () {
    late AuthRepositoryMock authRepo;

    setUp(() {
      authRepo = AuthRepositoryMock();
    });

    test('login with valid demo credentials returns AuthSession', () async {
      final session = await authRepo.login(
        email: AuthRepositoryMock.demoEmail,
        password: AuthRepositoryMock.demoPassword,
      );

      expect(session.user.email, equals(AuthRepositoryMock.demoEmail));
      expect(session.accessToken, isNotEmpty);
      expect(session.user.memberships, isNotEmpty);
      expect(session.user.memberships.first.role, equals(RoleType.family));
    });

    test('login with invalid credentials throws ApiException', () async {
      expect(
        () async => await authRepo.login(
          email: 'wrong@agecare.app',
          password: 'badpassword',
        ),
        throwsA(isA<ApiException>()),
      );
    });

    test('register creates a new user session', () async {
      final session = await authRepo.register(
        fullName: 'Carlos Perez',
        email: 'carlos.perez@example.com',
        password: 'securePassword123',
        phone: '+56912345678',
      );

      expect(session.user.fullName, equals('Carlos Perez'));
      expect(session.user.email, equals('carlos.perez@example.com'));
      expect(session.accessToken, isNotEmpty);
    });

    test('me returns current logged in user', () async {
      await authRepo.login(
        email: AuthRepositoryMock.demoEmail,
        password: AuthRepositoryMock.demoPassword,
      );

      final user = await authRepo.me();
      expect(user.email, equals(AuthRepositoryMock.demoEmail));
    });

    test('logout resets session', () async {
      await authRepo.login(
        email: AuthRepositoryMock.demoEmail,
        password: AuthRepositoryMock.demoPassword,
      );

      await authRepo.logout('mock-refresh');
      final user = await authRepo.me();
      expect(user, isNotNull);
    });
  });
}

// Prueba de la capa de Mocks (AGE-105, criterio "Capa de Mocks configurada
// mediante AppConfig.useMocks para desarrollo offline/independiente").
//
// AppConfig.useMocks es bool.fromEnvironment('USE_MOCKS', defaultValue: true):
// sin pasar --dart-define, como corre esta suite, siempre vale true. Este
// test recorre los 13 repositorios de la app y confirma que cada provider
// resuelve de verdad a su implementación *Mock — no solo que "existe la
// clase", sino que el mecanismo de selección funciona.
import 'package:agecare_app/core/config/app_config.dart';
import 'package:agecare_app/features/alerts/data/alerts_repository.dart';
import 'package:agecare_app/features/auth/data/auth_repository.dart';
import 'package:agecare_app/features/caregiver/data/caregiver_repository.dart';
import 'package:agecare_app/features/comms/data/assistant_repository.dart';
import 'package:agecare_app/features/comms/data/chat_repository.dart';
import 'package:agecare_app/features/documents/data/documents_repository.dart';
import 'package:agecare_app/features/elder/data/elder_repository.dart';
import 'package:agecare_app/features/health/data/vitals_repository.dart';
import 'package:agecare_app/features/home/data/dashboard_repository.dart';
import 'package:agecare_app/features/marketplace/data/marketplace_repository.dart';
import 'package:agecare_app/features/medications/data/medications_repository.dart';
import 'package:agecare_app/features/patients/data/patients_repository.dart';
import 'package:agecare_app/features/profile/data/profile_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppConfig.useMocks es true por defecto (sin --dart-define)', () {
    expect(AppConfig.useMocks, isTrue);
  });

  test('cada repositorio resuelve a su implementacion Mock cuando useMocks es true', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final casos = <String, Object>{
      'alertsRepositoryProvider': container.read(alertsRepositoryProvider),
      'authRepositoryProvider': container.read(authRepositoryProvider),
      'caregiverRepositoryProvider': container.read(caregiverRepositoryProvider),
      'assistantRepositoryProvider': container.read(assistantRepositoryProvider),
      'chatRepositoryProvider': container.read(chatRepositoryProvider),
      'documentsRepositoryProvider': container.read(documentsRepositoryProvider),
      'elderRepositoryProvider': container.read(elderRepositoryProvider),
      'vitalsRepositoryProvider': container.read(vitalsRepositoryProvider),
      'dashboardRepositoryProvider': container.read(dashboardRepositoryProvider),
      'marketplaceRepositoryProvider': container.read(marketplaceRepositoryProvider),
      'medicationsRepositoryProvider': container.read(medicationsRepositoryProvider),
      'patientsRepositoryProvider': container.read(patientsRepositoryProvider),
      'profileRepositoryProvider': container.read(profileRepositoryProvider),
    };

    expect(casos.length, 13, reason: 'deberian ser los 13 repositorios de la app');

    for (final entry in casos.entries) {
      expect(
        entry.value.runtimeType.toString(),
        endsWith('Mock'),
        reason: '${entry.key} deberia resolver a su *Mock con useMocks=true, '
            'pero resolvio a ${entry.value.runtimeType}',
      );
    }
  });
}

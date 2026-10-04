// Pruebas de la barra superior de selección de paciente (AGE-206 / DAC05-56).
//
// Cubre los dos criterios de aceptación del ticket:
//  - Con 2+ pacientes vinculados, al desplegar el selector se ve la lista
//    completa y se puede cambiar el paciente activo en 1 toque.
//  - Al cambiar de paciente activo, los providers de Riverpod que dependen
//    de selectedPatientProvider refrescan solos sus datos.
// Y además el caso de borde explícito en el ticket: con 1 solo paciente
// vinculado, la barra muestra el contexto pero no ofrece cambiar.
import 'package:agecare_app/core/theme/app_theme.dart';
import 'package:agecare_app/features/auth/domain/models.dart';
import 'package:agecare_app/features/patients/application/patients_providers.dart';
import 'package:agecare_app/features/patients/data/patients_repository.dart';
import 'package:agecare_app/features/patients/domain/models.dart';
import 'package:agecare_app/features/shell/patient_selector_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Repositorio de prueba con un único paciente vinculado (sin usar
/// PatientsRepositoryMock, que trae 2 de fábrica).
class _SinglePatientRepo implements PatientsRepository {
  static const _only = PatientCard(
    patientId: 'p-unico',
    fullName: 'Mario Soto',
    role: RoleType.family,
    wellbeingStatus: WellbeingStatus.ok,
  );

  @override
  Future<List<PatientCard>> listMyPatients() async => const [_only];

  @override
  Future<Patient> getPatient(String patientId) async => Patient(
        patientId: 'p-unico',
        fullName: 'Mario Soto',
        birthDate: DateTime(1950, 1, 1),
        sex: 'male',
      );

  @override
  Future<Patient> createPatient(NewPatient data) => throw UnimplementedError();

  @override
  Future<Invitation> invite(
          {required String patientId, required RoleType role, String? email}) =>
      throw UnimplementedError();

  @override
  Future<PatientCard> acceptInvitation(String code) =>
      throw UnimplementedError();

  @override
  Future<WearableStatus> wearableStatus(String patientId) =>
      throw UnimplementedError();

  @override
  Future<List<CircleMember>> listCircleMembers(String patientId) =>
      throw UnimplementedError();

  @override
  Future<Invitation> resendInvitation(String patientId, String memberId) =>
      throw UnimplementedError();

  @override
  Future<void> revokeInvitation(String patientId, String memberId) =>
      throw UnimplementedError();

  @override
  Future<void> revokeMember(String patientId, String memberId) =>
      throw UnimplementedError();
}

/// Monta la barra junto con [selectedPatientDetailProvider] visible, para
/// poder comprobar que un provider que depende del paciente seleccionado
/// se refresca solo cuando éste cambia.
class _Harness extends ConsumerWidget {
  const _Harness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(selectedPatientDetailProvider);
    return Scaffold(
      body: Column(
        children: [
          const PatientSelectorBar(),
          Text('detalle:${detail.value?.fullName ?? '-'}'),
        ],
      ),
    );
  }
}

void main() {
  Future<void> pumpHarness(WidgetTester tester, PatientsRepository repo) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [patientsRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(theme: AppTheme.light(), home: const _Harness()),
    ));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'con 1 solo paciente vinculado, la barra muestra su nombre y no se puede desplegar',
      (tester) async {
    await pumpHarness(tester, _SinglePatientRepo());

    expect(find.text('Mario Soto'), findsOneWidget);
    // Sin flecha de "desplegar": con un solo paciente no hay nada que elegir.
    expect(find.byIcon(Icons.expand_more_rounded), findsNothing);

    // Tocar la barra no debe abrir ningún selector.
    await tester.tap(find.byKey(const Key('patientSelectorBar_tap')));
    await tester.pumpAndSettle();
    expect(find.text('Cambiar de paciente'), findsNothing);
  });

  testWidgets(
      'con 2 o mas pacientes, despliega la lista y cambia el paciente activo en 1 toque',
      (tester) async {
    await pumpHarness(tester, PatientsRepositoryMock());

    // Auto-seleccionado el primero de la lista al cargar.
    expect(find.text('Elena Ramírez'), findsOneWidget);
    expect(find.byIcon(Icons.expand_more_rounded), findsOneWidget);

    await tester.tap(find.byKey(const Key('patientSelectorBar_tap')));
    await tester.pumpAndSettle();

    // Se ve la lista completa de pacientes vinculados.
    expect(find.text('Cambiar de paciente'), findsOneWidget);
    expect(find.byKey(const Key('patientSelectorBar_option_p-elena')),
        findsOneWidget);
    expect(find.byKey(const Key('patientSelectorBar_option_p-jose')),
        findsOneWidget);

    // 1 toque sobre José cambia el contexto activo.
    await tester.tap(find.byKey(const Key('patientSelectorBar_option_p-jose')));
    await tester.pumpAndSettle();

    expect(find.text('José Ramírez'), findsOneWidget);
    expect(find.text('Elena Ramírez'), findsNothing);
  });

  testWidgets(
      'al cambiar de paciente activo, los providers que dependen de el refrescan solos sus datos',
      (tester) async {
    await pumpHarness(tester, PatientsRepositoryMock());
    await tester.pump(const Duration(seconds: 1));

    // selectedPatientDetailProvider ya cargó el detalle de Elena (1er paciente).
    expect(find.text('detalle:Elena Ramírez'), findsOneWidget);

    await tester.tap(find.byKey(const Key('patientSelectorBar_tap')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('patientSelectorBar_option_p-jose')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));

    // Sin invalidar nada a mano: selectedPatientDetailProvider observa
    // selectedPatientProvider y se reconstruyó solo con el nuevo paciente.
    expect(find.text('detalle:José Ramírez'), findsOneWidget);
  });
}

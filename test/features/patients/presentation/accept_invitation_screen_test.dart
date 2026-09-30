// Prueba de la pantalla donde el invitado ingresa el codigo de 6 digitos
// (AGE-205 / DAC05-7). Monta la pantalla real con un repositorio Mock
// compartido: primero se genera una invitacion "de verdad" (como haria
// InviteMemberScreen), y se comprueba que ingresar ese codigo en esta
// pantalla efectivamente une al paciente — y que un codigo invalido
// muestra el error en el campo, sin romper la pantalla.
//
// Nota sobre tester.runAsync(): PatientsRepositoryMock simula latencia con
// Future.delayed real. Dentro de un testWidgets, el reloj lo controla el
// binding de pruebas: un Future.delayed llamado *antes* de montar la
// pantalla (fuera de cualquier ciclo de pump) nunca se resuelve solo y
// cuelga la prueba para siempre. runAsync corre ese fragmento en una zona
// con reloj real para que el delay sí se cumpla.
import 'package:agecare_app/core/theme/app_theme.dart';
import 'package:agecare_app/features/auth/domain/models.dart';
import 'package:agecare_app/features/patients/data/patients_repository.dart';
import 'package:agecare_app/features/patients/presentation/accept_invitation_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpScreen(WidgetTester tester, PatientsRepositoryMock repo) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [patientsRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const AcceptInvitationScreen(),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('con el codigo correcto muestra la pantalla de exito', (tester) async {
    final repo = PatientsRepositoryMock();
    final invitation = (await tester.runAsync(
        () => repo.invite(patientId: 'p-elena', role: RoleType.caregiver)))!;

    await pumpScreen(tester, repo);

    await tester.enterText(find.byType(TextField), invitation.code);
    await tester.tap(find.widgetWithText(FilledButton, 'Unirme'));
    await tester.pumpAndSettle();

    expect(find.text('Te uniste al cuidado de Elena Ramírez'), findsOneWidget);
    expect(find.text('Tu rol: Cuidadora'), findsOneWidget);
  });

  testWidgets('con un codigo invalido muestra el error y no avanza', (tester) async {
    final repo = PatientsRepositoryMock();
    await pumpScreen(tester, repo);

    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.widgetWithText(FilledButton, 'Unirme'));
    await tester.pumpAndSettle();

    expect(find.textContaining('no es válido'), findsOneWidget);
    // Sigue en el formulario, no paso a la pantalla de éxito.
    expect(find.text('Ingresa el código de 6 dígitos'), findsOneWidget);
  });

  testWidgets('con menos de 6 digitos pide completar el codigo sin llamar al repositorio',
      (tester) async {
    final repo = PatientsRepositoryMock();
    await pumpScreen(tester, repo);

    await tester.enterText(find.byType(TextField), '123');
    await tester.tap(find.widgetWithText(FilledButton, 'Unirme'));
    await tester.pump();

    expect(find.text('El código tiene 6 dígitos.'), findsOneWidget);
  });
}

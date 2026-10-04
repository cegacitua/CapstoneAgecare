// Prueba de la invitacion por codigo (AGE-205 / DAC05-7): generar un
// codigo de 6 digitos y validarlo del otro lado.
import 'package:agecare_app/core/network/api_client.dart';
import 'package:agecare_app/features/auth/domain/models.dart';
import 'package:agecare_app/features/patients/data/patients_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('invite() genera un codigo de exactamente 6 digitos numericos', () async {
    final repo = PatientsRepositoryMock();

    final invitation =
        await repo.invite(patientId: 'p-elena', role: RoleType.caregiver);

    expect(invitation.code, hasLength(6));
    expect(int.tryParse(invitation.code), isNotNull);
    expect(invitation.role, RoleType.caregiver);
  });

  test('acceptInvitation() con el codigo correcto vincula al paciente con el rol invitado',
      () async {
    final repo = PatientsRepositoryMock();
    final invitation =
        await repo.invite(patientId: 'p-jose', role: RoleType.doctor);

    final card = await repo.acceptInvitation(invitation.code);

    expect(card.patientId, 'p-jose');
    expect(card.role, RoleType.doctor);

    // Y ademas queda en la lista de pacientes del usuario que se unio.
    final misPacientes = await repo.listMyPatients();
    expect(misPacientes.any((p) => p.patientId == 'p-jose' && p.role == RoleType.doctor),
        isTrue);
  });

  test('acceptInvitation() con un codigo que nunca existio lanza ApiException', () async {
    final repo = PatientsRepositoryMock();

    await expectLater(
      repo.acceptInvitation('000000'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'INVALID_CODE')),
    );
  });

  test('un codigo ya usado no sirve una segunda vez (un solo uso)', () async {
    final repo = PatientsRepositoryMock();
    final invitation =
        await repo.invite(patientId: 'p-elena', role: RoleType.caregiver);

    await repo.acceptInvitation(invitation.code); // primer uso: ok

    await expectLater(
      repo.acceptInvitation(invitation.code), // segundo uso: ya no deberia servir
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'INVALID_CODE')),
    );
  });

  test('Invitation.isExpired refleja si expiresAt ya paso', () async {
    final repo = PatientsRepositoryMock();
    final invitation =
        await repo.invite(patientId: 'p-elena', role: RoleType.family);

    // Recien creada: vale por 48 h, no deberia estar vencida.
    expect(invitation.isExpired, isFalse);
    expect(invitation.timeLeft.inHours, closeTo(48, 1));
  });
}

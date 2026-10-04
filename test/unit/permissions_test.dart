import 'package:flutter_test/flutter_test.dart';
import 'package:agecare_app/features/auth/domain/models.dart';
import 'package:agecare_app/features/patients/data/patients_repository.dart';

void main() {
  group('AGE-207 Permissions & Circle of Care Unit Tests', () {
    late PatientsRepositoryMock patientsRepo;

    setUp(() {
      patientsRepo = PatientsRepositoryMock();
    });

    test('listCircleMembers returns active circle members and pending invitations', () async {
      final members = await patientsRepo.listCircleMembers('p-elena');

      expect(members, isNotEmpty);
      expect(members.any((m) => m.role == RoleType.caregiver), isTrue);
      expect(members.any((m) => m.role == RoleType.doctor), isTrue);
      expect(members.any((m) => m.role == RoleType.family), isTrue);
    });

    test('invite creates a new pending caregiver invitation in the circle', () async {
      final invitation = await patientsRepo.invite(
        patientId: 'p-elena',
        role: RoleType.caregiver,
        email: 'nueva.cuidadora@agecare.app',
      );

      expect(invitation.code, isNotEmpty);

      final members = await patientsRepo.listCircleMembers('p-elena');
      expect(members.any((m) => m.email == 'nueva.cuidadora@agecare.app'), isTrue);
    });

    test('revokeMember desvincula de inmediato a la cuidadora del círculo de cuidado', () async {
      final initialMembers = await patientsRepo.listCircleMembers('p-elena');
      final targetMember = initialMembers.firstWhere((m) => m.role == RoleType.caregiver);

      await patientsRepo.revokeMember('p-elena', targetMember.memberId);

      final updatedMembers = await patientsRepo.listCircleMembers('p-elena');
      expect(updatedMembers.any((m) => m.memberId == targetMember.memberId), isFalse);
    });

    test('revokeInvitation cancela una invitación pendiente', () async {
      final initialMembers = await patientsRepo.listCircleMembers('p-elena');
      final pendingMember = initialMembers.firstWhere((m) => m.isPending);

      await patientsRepo.revokeInvitation('p-elena', pendingMember.memberId);

      final updatedMembers = await patientsRepo.listCircleMembers('p-elena');
      expect(updatedMembers.any((m) => m.memberId == pendingMember.memberId), isFalse);
    });

    test('resendInvitation regenera enlace de invitación para el usuario', () async {
      final members = await patientsRepo.listCircleMembers('p-elena');
      final pendingMember = members.firstWhere((m) => m.isPending);

      final resentInv = await patientsRepo.resendInvitation('p-elena', pendingMember.memberId);

      expect(resentInv.code, isNotEmpty);
      expect(resentInv.code.length, 6);
    });
  });
}

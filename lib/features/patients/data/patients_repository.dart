import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/domain/models.dart';
import '../domain/models.dart';

abstract class PatientsRepository {
  Future<List<PatientCard>> listMyPatients();
  Future<Patient> getPatient(String patientId);
  Future<Patient> createPatient(NewPatient data);
  Future<Invitation> invite({
    required String patientId,
    required RoleType role,
    String? email,
  });
  Future<void> acceptInvitation(String token);
  Future<WearableStatus> wearableStatus(String patientId);

  // Gestión de Permisos y Círculo de Cuidado (ticket AGE-207)
  Future<List<CircleMember>> listCircleMembers(String patientId);
  Future<void> revokeMember(String patientId, String memberId);
  Future<void> revokeInvitation(String patientId, String invitationId);
  Future<Invitation> resendInvitation(String patientId, String invitationId);
}

// ---------------------------------------------------------------------------
// HTTP
// ---------------------------------------------------------------------------
class PatientsRepositoryHttp implements PatientsRepository {
  PatientsRepositoryHttp(this._api);
  final ApiClient _api;

  @override
  Future<List<PatientCard>> listMyPatients() async {
    final data = await _api.get<Map<String, dynamic>>('/patients');
    return ((data['items'] ?? []) as List)
        .map((e) => PatientCard.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Patient> getPatient(String patientId) async {
    final data = await _api.get<Map<String, dynamic>>('/patients/$patientId');
    return Patient.fromJson(data);
  }

  @override
  Future<Patient> createPatient(NewPatient data) async {
    final res =
        await _api.post<Map<String, dynamic>>('/patients', data: data.toJson());
    return getPatient(res['patient_id'] as String);
  }

  @override
  Future<Invitation> invite(
      {required String patientId, required RoleType role, String? email}) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/patients/$patientId/invitations',
      data: {'role': role.apiValue, if (email != null) 'email': email},
    );
    return Invitation.fromJson(res);
  }

  @override
  Future<void> acceptInvitation(String token) =>
      _api.post<void>('/invitations/accept', data: {'token': token});

  @override
  Future<WearableStatus> wearableStatus(String patientId) async {
    final data =
        await _api.get<Map<String, dynamic>>('/patients/$patientId/wearable/status');
    return WearableStatus.fromJson(data);
  }

  @override
  Future<List<CircleMember>> listCircleMembers(String patientId) async {
    final data = await _api.get<Map<String, dynamic>>('/patients/$patientId/members');
    return ((data['items'] ?? []) as List)
        .map((e) => CircleMember.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> revokeMember(String patientId, String memberId) =>
      _api.delete<void>('/patients/$patientId/members/$memberId');

  @override
  Future<void> revokeInvitation(String patientId, String invitationId) =>
      _api.delete<void>('/patients/$patientId/invitations/$invitationId');

  @override
  Future<Invitation> resendInvitation(String patientId, String invitationId) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/patients/$patientId/invitations/$invitationId/resend',
    );
    return Invitation.fromJson(res);
  }
}

// ---------------------------------------------------------------------------
// Mock
// ---------------------------------------------------------------------------
class PatientsRepositoryMock implements PatientsRepository {
  final Map<String, Patient> _patients = {
    'p-elena': Patient(
      patientId: 'p-elena',
      fullName: 'Elena Ramírez',
      birthDate: DateTime(1948, 3, 12),
      sex: 'female',
      conditions: const ['Hipertensión', 'Artrosis'],
      wearable: WearableStatus(
        wearableId: 'w-1',
        lastSyncAt: DateTime.now().subtract(const Duration(minutes: 18)),
        batteryPct: 72,
      ),
    ),
    'p-jose': Patient(
      patientId: 'p-jose',
      fullName: 'José Ramírez',
      birthDate: DateTime(1945, 11, 2),
      sex: 'male',
      conditions: const ['Diabetes tipo 2'],
      wearable: WearableStatus(
        wearableId: 'w-2',
        lastSyncAt: DateTime.now().subtract(const Duration(hours: 3)),
        batteryPct: 15,
        isStale: true,
      ),
    ),
  };

  final List<CircleMember> _mockMembers = [
    CircleMember(
      memberId: 'm-1',
      fullName: 'Claudia Iosue',
      email: 'claudia.cuidadora@agecare.app',
      role: RoleType.caregiver,
      status: InvitationState.accepted,
      joinedAt: DateTime.now().subtract(const Duration(days: 30)),
    ),
    CircleMember(
      memberId: 'm-2',
      fullName: 'Dr. Felipe Varas',
      email: 'felipe.medico@agecare.app',
      role: RoleType.doctor,
      status: InvitationState.accepted,
      joinedAt: DateTime.now().subtract(const Duration(days: 14)),
    ),
    CircleMember(
      memberId: 'm-3',
      fullName: 'Franco Barra (Familiar)',
      email: 'franco.familiar@agecare.app',
      role: RoleType.family,
      status: InvitationState.accepted,
      joinedAt: DateTime.now().subtract(const Duration(days: 60)),
    ),
    CircleMember(
      memberId: 'm-4',
      fullName: 'Cuidadora Reemplazo (Pendiente)',
      email: 'reemplazo@agecare.app',
      role: RoleType.caregiver,
      status: InvitationState.pending,
      joinedAt: DateTime.now().subtract(const Duration(hours: 4)),
    ),
  ];

  @override
  Future<List<PatientCard>> listMyPatients() async {
    await Future.delayed(const Duration(milliseconds: 350));
    return [
      const PatientCard(
        patientId: 'p-elena',
        fullName: 'Elena Ramírez',
        role: RoleType.family,
        wellbeingStatus: WellbeingStatus.ok,
      ),
      const PatientCard(
        patientId: 'p-jose',
        fullName: 'José Ramírez',
        role: RoleType.family,
        wellbeingStatus: WellbeingStatus.warning,
        activeAlertsCount: 1,
        topReason: 'Wearable sin datos desde hace 3 h',
      ),
    ];
  }

  @override
  Future<Patient> getPatient(String patientId) async {
    await Future.delayed(const Duration(milliseconds: 250));
    final p = _patients[patientId];
    if (p == null) {
      throw ApiException(
          statusCode: 404,
          code: 'NOT_FOUND',
          message: 'El recurso solicitado no existe o no está disponible.');
    }
    return p;
  }

  @override
  Future<Patient> createPatient(NewPatient data) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final id = 'p-${DateTime.now().millisecondsSinceEpoch}';
    final patient = Patient(
      patientId: id,
      fullName: data.fullName,
      birthDate: data.birthDate,
      sex: data.sex,
      conditions: data.conditions,
      notes: data.notes,
    );
    _patients[id] = patient;
    return patient;
  }

  @override
  Future<Invitation> invite(
      {required String patientId, required RoleType role, String? email}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final token = 'inv-${DateTime.now().millisecondsSinceEpoch}';
    final newMember = CircleMember(
      memberId: 'm-${DateTime.now().millisecondsSinceEpoch}',
      fullName: email ?? 'Invitado Pendiente',
      email: email ?? 'sin_correo@agecare.app',
      role: role,
      status: InvitationState.pending,
      joinedAt: DateTime.now(),
    );
    _mockMembers.add(newMember);
    return Invitation(
      invitationId: newMember.memberId,
      token: token,
      inviteUrl: 'https://app.agecare.app/invite/$token',
      expiresAt: DateTime.now().add(const Duration(days: 7)),
    );
  }

  @override
  Future<void> acceptInvitation(String token) async {
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  Future<WearableStatus> wearableStatus(String patientId) async {
    final p = await getPatient(patientId);
    return p.wearable ?? const WearableStatus();
  }

  @override
  Future<List<CircleMember>> listCircleMembers(String patientId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return List.from(_mockMembers);
  }

  @override
  Future<void> revokeMember(String patientId, String memberId) async {
    await Future.delayed(const Duration(milliseconds: 350));
    _mockMembers.removeWhere((m) => m.memberId == memberId);
  }

  @override
  Future<void> revokeInvitation(String patientId, String invitationId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _mockMembers.removeWhere((m) => m.memberId == invitationId);
  }

  @override
  Future<Invitation> resendInvitation(String patientId, String invitationId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final token = 'inv-resend-${DateTime.now().millisecondsSinceEpoch}';
    return Invitation(
      invitationId: invitationId,
      token: token,
      inviteUrl: 'https://app.agecare.app/invite/$token',
      expiresAt: DateTime.now().add(const Duration(days: 7)),
    );
  }
}

final patientsRepositoryProvider = Provider<PatientsRepository>((ref) {
  if (AppConfig.useMocks) return PatientsRepositoryMock();
  return PatientsRepositoryHttp(ref.watch(apiClientProvider));
});

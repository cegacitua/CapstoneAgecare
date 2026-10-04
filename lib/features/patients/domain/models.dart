import '../../../core/theme/app_theme.dart';
import '../../auth/domain/models.dart';

class WearableStatus {
  const WearableStatus({
    this.wearableId,
    this.lastSyncAt,
    this.batteryPct,
    this.isStale = false,
  });

  final String? wearableId;
  final DateTime? lastSyncAt;
  final int? batteryPct;
  final bool isStale;

  bool get isLinked => wearableId != null;

  factory WearableStatus.fromJson(Map<String, dynamic> json) => WearableStatus(
        wearableId: json['wearable_id'] as String?,
        lastSyncAt: json['last_sync_at'] != null
            ? DateTime.parse(json['last_sync_at'] as String)
            : null,
        batteryPct: json['battery_pct'] as int?,
        isStale: (json['is_stale'] ?? false) as bool,
      );
}

class Patient {
  const Patient({
    required this.patientId,
    required this.fullName,
    required this.birthDate,
    this.sex,
    this.photoUrl,
    this.conditions = const [],
    this.notes,
    this.wearable,
  });

  final String patientId;
  final String fullName;
  final DateTime birthDate;
  final String? sex;
  final String? photoUrl;
  final List<String> conditions;
  final String? notes;
  final WearableStatus? wearable;

  int get age {
    final now = DateTime.now();
    var years = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      years--;
    }
    return years;
  }

  factory Patient.fromJson(Map<String, dynamic> json) => Patient(
        patientId: json['patient_id'] as String,
        fullName: json['full_name'] as String,
        birthDate: DateTime.parse(json['birth_date'] as String),
        sex: json['sex'] as String?,
        photoUrl: json['photo_url'] as String?,
        conditions:
            ((json['conditions'] ?? []) as List).map((e) => e.toString()).toList(),
        notes: json['notes'] as String?,
        wearable: json['wearable'] != null
            ? WearableStatus.fromJson(json['wearable'] as Map<String, dynamic>)
            : null,
      );
}

/// Tarjeta de paciente para el selector y el tablero multi-paciente.
class PatientCard {
  const PatientCard({
    required this.patientId,
    required this.fullName,
    this.photoUrl,
    required this.role,
    required this.wellbeingStatus,
    this.activeAlertsCount = 0,
    this.topReason,
  });

  final String patientId;
  final String fullName;
  final String? photoUrl;
  final RoleType role;
  final WellbeingStatus wellbeingStatus;
  final int activeAlertsCount;
  final String? topReason;

  factory PatientCard.fromJson(Map<String, dynamic> json) => PatientCard(
        patientId: json['patient_id'] as String,
        fullName: json['full_name'] as String,
        photoUrl: json['photo_url'] as String?,
        role: RoleType.fromApi((json['role'] ?? 'family') as String),
        wellbeingStatus:
            WellbeingStatus.fromApi((json['wellbeing_status'] ?? 'ok') as String),
        activeAlertsCount: (json['active_alerts_count'] ?? 0) as int,
        topReason: json['top_reason'] as String?,
      );
}

/// Solicitud de creación de paciente.
class NewPatient {
  const NewPatient({
    required this.fullName,
    required this.birthDate,
    this.sex,
    this.conditions = const [],
    this.notes,
  });

  final String fullName;
  final DateTime birthDate;
  final String? sex;
  final List<String> conditions;
  final String? notes;

  Map<String, dynamic> toJson() => {
        'full_name': fullName,
        'birth_date':
            '${birthDate.year.toString().padLeft(4, '0')}-${birthDate.month.toString().padLeft(2, '0')}-${birthDate.day.toString().padLeft(2, '0')}',
        if (sex != null) 'sex': sex,
        if (conditions.isNotEmpty) 'conditions': conditions,
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
      };
}

/// Invitación al círculo de cuidado (AGE-205 / DAC05-7): un código numérico
/// de 6 dígitos, no un enlace — vence 48 h después de crearse.
class Invitation {
  const Invitation({
    required this.invitationId,
    required this.code,
    required this.role,
    required this.expiresAt,
  });

  final String invitationId;
  final String code;
  final RoleType role;
  final DateTime expiresAt;

  Duration get timeLeft => expiresAt.difference(DateTime.now());
  bool get isExpired => timeLeft.isNegative;

  factory Invitation.fromJson(Map<String, dynamic> json) => Invitation(
        invitationId: json['invitation_id'] as String,
        code: json['code'] as String,
        role: RoleType.fromApi(json['role'] as String),
        expiresAt: DateTime.parse(json['expires_at'] as String),
      );
}

enum InvitationState {
  pending('pending', 'Pendiente'),
  accepted('accepted', 'Aceptada'),
  expired('expired', 'Vencida');

  const InvitationState(this.apiValue, this.label);
  final String apiValue;
  final String label;

  static InvitationState fromApi(String v) => InvitationState.values.firstWhere(
        (e) => e.apiValue == v,
        orElse: () => InvitationState.pending,
      );
}

class CircleMember {
  const CircleMember({
    required this.memberId,
    required this.fullName,
    required this.email,
    required this.role,
    required this.status,
    required this.joinedAt,
  });

  final String memberId;
  final String fullName;
  final String email;
  final RoleType role;
  final InvitationState status;
  final DateTime joinedAt;

  bool get isPending => status == InvitationState.pending;
  bool get isExpired => status == InvitationState.expired;
  bool get isAccepted => status == InvitationState.accepted;

  factory CircleMember.fromJson(Map<String, dynamic> json) => CircleMember(
        memberId: json['member_id'] as String,
        fullName: json['full_name'] as String,
        email: json['email'] as String,
        role: RoleType.fromApi((json['role'] ?? 'caregiver') as String),
        status: InvitationState.fromApi((json['status'] ?? 'accepted') as String),
        joinedAt: DateTime.parse(json['joined_at'] as String),
      );
}

